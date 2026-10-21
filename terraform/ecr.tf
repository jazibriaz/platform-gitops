# Private container registry for the PCForge image
resource "aws_ecr_repository" "pcforge" {
  name                 = "pcforge"
  image_tag_mutability = "IMMUTABLE" # a tag (git SHA) can never be overwritten, so what Git says is what runs
  force_delete         = true        # lab only: lets terraform destroy remove it even with images inside

  image_scanning_configuration {
    scan_on_push = true # basic CVE scan on every push
  }
}

# Keep the registry from growing forever: only the last 20 images are kept
resource "aws_ecr_lifecycle_policy" "pcforge" {
  repository = aws_ecr_repository.pcforge.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
