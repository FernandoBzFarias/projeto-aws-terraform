# Projeto E-commerce AWS com Terraform

Este projeto realiza o provisionamento completo de uma infraestrutura para e-commerce na AWS utilizando **Terraform** (Infraestrutura como Código), simulando uma arquitetura de microsserviços com comunicação assíncrona.

---

## Arquitetura da Solução

**Fluxo dos Dados:**
```text
Usuário → EC2 (API Flask) → SQS → Lambda → CloudWatch Logs
```

1. **VPC & Rede**: VPC dedicada com subnet pública, Internet Gateway e Route Table.
2. **Segurança**: Security Group liberando portas 80 (HTTP), 5000 e 22 (SSH).
3. **Compute (EC2)**: Instância `t2.micro` executando duas APIs em Python (Flask):
   - `GET /produtos`: Retorna uma lista de produtos cadastrados.
   - `POST /pedidos`: Recebe novos pedidos e envia mensagens para a fila SQS.
4. **Mensageria (SQS)**: Fila `pedidos-a-processar` para desacoplamento de serviços.
5. **Serverless (Lambda & CloudWatch)**: Função Lambda acionada via trigger no SQS, processando as mensagens recebidas e registrando os logs no CloudWatch Logs.

---

## Estrutura do Código Terraform

- `variables.tf`: Definições de variáveis (região, bloco CIDR, nomes base).
- `vpc.tf`: Recursos de rede (VPC, Subnet, Internet Gateway, Tabela de Roteamento).
- `security.tf`: Security Group e regras de firewall para a EC2.
- `sqs.tf`: Fila SQS `pedidos-a-processar`.
- `lambda.tf`: Função AWS Lambda, perfil do IAM e gatilho SQS.
- `ec2.tf`: Instância EC2, perfil do IAM e script de inicialização (`user_data`) para subir as APIs.

---

## Como Executar o Projetos

### Pré-requisitos
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`).
- [Terraform](https://www.terraform.io/) instalado.

### Passo a Passo

1. Inicializar o repositório Terraform:
   ```bash
   terraform init
   ```

2. Validar o plano de execução:
   ```bash
   terraform plan
   ```

3. Provisionar os recursos na AWS:
   ```bash
   terraform apply -auto-approve
   ```

4. Após a execução, o Terraform exibirá o IP público da instância EC2 (`ec2_public_ip`).

---

## Como Testar a Aplicação

### 1. Listar Produtos (GET)
```bash
curl http://<IP_PUBLICO_EC2>/produtos
```

### 2. Enviar um Pedido (POST)
```bash
curl -X POST http://<IP_PUBLICO_EC2>/pedidos \
     -H "Content-Type: application/json" \
     -d '{"id_pedido": 1001, "cliente": "Fernanda", "valor": 3500.00, "item": "Notebook"}'
```

---

## Evidências de Funcionamento

> **Nota:** Adicione os prints de tela da sua execução aqui no repositório.

1. **Saída do `terraform apply`**: Exibindo a criação dos 16 recursos e o IP público da EC2.
2. **EC2 Rodando**: Print do console da AWS mostrando a instância em execução na região `us-east-1`.
3. **Mensagem no SQS**: Print do teste executado via terminal enviando o pedido.
4. **Logs no CloudWatch**: Print do Log Stream no CloudWatch confirmando que a Lambda processou a mensagem enviada ao SQS.

---

## Limpeza dos Recursos

Para destruir todos os recursos criados na AWS e evitar cobranças:

```bash
terraform destroy -auto-approve
```