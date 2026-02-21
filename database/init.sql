CREATE TABLE IF NOT EXISTS prompts (
    id SERIAL PRIMARY KEY,
    prompt_text TEXT NOT NULL
);

INSERT INTO prompts (prompt_text) VALUES 
('Explain the concept of CI/CD and its benefits.'),
('What is the difference between Docker and Virtual Machines?'),
('How does Kubernetes handle container orchestration?'),
('Explain Infrastructure as Code (IaC) using Terraform as an example.'),
('What are the advantages of a microservices architecture over a monolithic one?');
