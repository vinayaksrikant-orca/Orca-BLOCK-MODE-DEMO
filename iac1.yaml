resource "aws_security_group" "bad_sg" {
  name        = "open-to-the-world"
  description = "This SG is a nightmare for AppSec"

  # 1. OPEN INBOUND TRAFFIC (Scanner: IaC / Checkov)
  # Allowing 0.0.0.0/0 on port 22 (SSH) is a major finding.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 2. UNRESTRICTED OUTBOUND (Scanner: IaC)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "insecure_db" {
  allocated_storage    = 10
  engine              = "mysql"
  instance_class      = "db.t3.micro"
  
  # 3. PUBLICLY ACCESSIBLE DB (Scanner: IaC)
  publicly_accessible = true

  # 4. ENCRYPTION DISABLED (Scanner: IaC)
  storage_encrypted   = false
  
  skip_final_snapshot = true
}