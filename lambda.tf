resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<EOF
import json

def lambda_handler(event, context):
    for record in event['Records']:
        payload = record['body']
        print(f"Pedido recebido do SQS com sucesso: {payload}")
    return {
        'statusCode': 200,
        'body': json.dumps('Processamento concluido!')
    }
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "processa_pedidos" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-processa-pedidos"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.pedidos_queue.arn
  function_name    = aws_lambda_function.processa_pedidos.arn
  batch_size       = 1
  enabled          = true
}