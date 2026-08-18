data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_sqs_full" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.id

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y python3-pip
              pip3 install flask boto3

              mkdir -p /app
              cat << 'PYEOF' > /app/app.py
              from flask import Flask, jsonify, request
              import boto3
              import json

              app = Flask(__name__)
              sqs = boto3.client('sqs', region_name='us-east-1')
              QUEUE_URL = "${aws_sqs_queue.pedidos_queue.url}"

              @app.route('/produtos', methods=['GET'])
              def get_produtos():
                  produtos = [
                      {"id": 1, "nome": "Notebook", "preco": 3500.00},
                      {"id": 2, "nome": "Mouse Sem Fio", "preco": 120.00},
                      {"id": 3, "nome": "Teclado Mecanico", "preco": 250.00}
                  ]
                  return jsonify(produtos), 200

              @app.route('/pedidos', methods=['POST'])
              def create_pedido():
                  dados = request.get_json()
                  if not dados:
                      return jsonify({"erro": "Dados invalidos"}), 400

                  response = sqs.send_message(
                      QueueUrl=QUEUE_URL,
                      MessageBody=json.dumps(dados)
                  )

                  return jsonify({
                      "mensagem": "Pedido enviado para a fila SQS com sucesso!",
                      "message_id": response.get('MessageId')
                  }), 201

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=80)
              PYEOF

              python3 /app/app.py &
              EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

output "ec2_public_ip" {
  description = "IP Publico da instancia EC2"
  value       = aws_instance.app_server.public_ip
}