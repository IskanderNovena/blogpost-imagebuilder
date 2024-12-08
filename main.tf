# Create a custom component
# Reference: https://docs.aws.amazon.com/imagebuilder/latest/userguide/create-custom-components.html
resource "aws_imagebuilder_component" "set_timezone" {
  name         = join("-", [var.name, "set-timezone-linux"])
  description  = "Sets the timezone to Europe/Amsterdam"
  platform     = "Linux"
  version      = "1.0.0"
  skip_destroy = false # Setting this to true retains any previous versions
  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [
        {
          name      = "SetTimezone"
          action    = "ExecuteBash"
          onFailure = "Abort"
          inputs = {
            commands = [
              "timedatectl set-timezone Europe/Amsterdam"
            ]
          }
        }
      ]
    }]
  })
}

# Create the Image recipe
resource "aws_imagebuilder_image_recipe" "this" {
  # Currently the service only supports x86-based images for import or export.
  name         = join("-", [var.name, "image-recipe"])
  parent_image = "arn:aws:imagebuilder:eu-west-1:aws:image/ubuntu-server-24-lts-x86/x.x.x" # "arn:aws:imagebuilder:eu-west-1:aws:image/amazon-linux-2023-ecs-optimized-x86/x.x.x"
  version      = "1.0.0"

  block_device_mapping {
    # The device name is the same device name as the root volume of the selected AMI,
    # which means we're overriding (some of) the root disk configuration in the AMI.
    # In this case we're increasing the size of the disk from 20 GB to 40 GB.
    device_name = "/dev/sda1" # "/dev/xvda"
    no_device   = false

    ebs {
      delete_on_termination = true
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = false
      iops                  = 3000
      throughput            = 125
    }
  }

  # Add the components to the recipe.
  # Recipes require a minimum of one build component, and can have a maximum of 20 build and test components in any combination.
  # Components are executed in the order they are listed here.
  component {
    # Here we're adding an AWS managed component to install the AWS CLI
    component_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/aws-cli-version-2-linux/x.x.x"
  }

  component {
    # Here we're adding our custom component
    component_arn = aws_imagebuilder_component.set_timezone.arn
  }

  systems_manager_agent {
    # Set this to false to keep the SSM agent installed after building the image.
    uninstall_after_build = true
  }

  lifecycle {
    # Adding resources to the replace_triggered_by, ensures that replacing a resource doesn't fail because of dependencies.
    # Instead, this resource will be replaced as well.
    replace_triggered_by = [
      aws_imagebuilder_component.set_timezone
    ]
  }
}

# Create the infrastructure configuration.
# This is where you specify the instance type(s) and VPC configuration to use for
# the instances used for building, testing and validating
resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                  = join("-", [var.name, "infrastructure-config"])
  description           = "Infrastructure Configuration for ${var.name}."
  instance_profile_name = aws_iam_instance_profile.imagebuilder_build.name
  instance_types        = var.instance_types
  sns_topic_arn         = aws_sns_topic.this.arn
  # If you want to keep the instance when an error occurs, so you can debug the issue, set this to false
  terminate_instance_on_failure = true
  # When not providing a subnet id and security group id(s),
  # Image Builder uses a subnet in the default VPC with the default security group.
  security_group_ids = [aws_security_group.imagebuilder_instances.id]
  subnet_id          = element(module.vpc.public_subnets, 0)

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1 # Increase this to 3 when building a container image
  }

  tags = {
    ImageType = "CustomisedUbuntu2404Image"
  }
}

# Create the distribution configuration.
# Here we configure exporting the AMI as an alternative image format to an S3 bucket.
# This can also be used to replicate the resulting AMI to a different region or account.
resource "aws_imagebuilder_distribution_configuration" "this" {
  name        = join("-", [var.name, "distribution-config"])
  description = "Distribution Configuration for ${var.name}."

  distribution {
    region = data.aws_region.current.name
    ami_distribution_configuration {
      name       = join("-", [var.name, "{{ imagebuilder:buildDate }}-{{ imagebuilder:buildVersion }}"])
      kms_key_id = null
      ami_tags = {
        ImageType = "CustomisedUbuntu2404Image"
      }
    }
    s3_export_configuration {
      role_name         = aws_iam_role.vmexport.name
      disk_image_format = upper(var.image_export_format)
      s3_bucket         = aws_s3_bucket.this.id
    }
  }
}

# Create the Image Builder pipeline
resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = join("-", [var.name, "image-pipeline"])
  description                      = "Pipeline to create the custom image for ${var.name}"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn

  image_scanning_configuration {
    # Amazon Inspector needs to be enabled for the account when setting this to true
    image_scanning_enabled = false
  }

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 720
  }

  # When changing the workflow from default, an execution role must also be provided
  execution_role = aws_iam_service_linked_role.imagebuilder.arn
  # If the Image Builder service-linked role was created outside of this project, comment out above line and uncomment the next.
  # Also comment out the service-linked role resource in iam.tf, lines 1-6.
  # execution_role = "arn:aws:iam::${data.aws_caller_identity.account.account_id}:role/aws-service-role/imagebuilder.amazonaws.com/AWSServiceRoleForImageBuilder"

  workflow {
    # We're setting an AWS managed workflow, that only executes Build-steps of the component. No testing or validation is done.
    workflow_arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:workflow/build/build-image/x.x.x"
  }

  # Here you can set one or more schedules, to automate image building.
  dynamic "schedule" {
    for_each = var.schedule_expression != null ? [1] : []
    content {
      schedule_expression = var.schedule_expression
    }
  }

  lifecycle {
    # Adding resources to the replace_triggered_by, ensures that replacing a resource doesn't fail because of dependencies.
    # Instead, this resource will be replaced as well.
    replace_triggered_by = [
      aws_imagebuilder_image_recipe.this
    ]
  }
}

resource "aws_cloudwatch_log_group" "imagebuilder" {
  name              = "/aws/imagebuilder/${aws_imagebuilder_image_recipe.this.name}"
  retention_in_days = 7
}
