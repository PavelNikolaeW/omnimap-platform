-- LLM Gateway tables initialization
\c llm_gateway;

-- Dialogs table
CREATE TABLE IF NOT EXISTS dialogs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL,
    title VARCHAR(255),
    system_prompt TEXT,
    model_name VARCHAR(100) NOT NULL,
    agent_config JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dialogs_user_id ON dialogs(user_id);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dialog_id UUID NOT NULL REFERENCES dialogs(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_dialog_id ON messages(dialog_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Token balances table
CREATE TABLE IF NOT EXISTS token_balances (
    user_id BIGINT PRIMARY KEY,
    balance BIGINT NOT NULL DEFAULT 0,
    "limit" BIGINT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Token transactions table
CREATE TABLE IF NOT EXISTS token_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(50) NOT NULL,
    dialog_id UUID REFERENCES dialogs(id) ON DELETE SET NULL,
    message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    admin_user_id BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_message_reason UNIQUE (message_id, reason)
);
CREATE INDEX IF NOT EXISTS idx_token_transactions_user_id ON token_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_token_transactions_created_at ON token_transactions(created_at);

-- Models table
CREATE TABLE IF NOT EXISTS models (
    name VARCHAR(100) PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    cost_per_1k_prompt_tokens NUMERIC(10, 6) NOT NULL,
    cost_per_1k_completion_tokens NUMERIC(10, 6) NOT NULL,
    context_window INTEGER NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_models_provider ON models(provider);

-- Insert default models
INSERT INTO models (name, provider, cost_per_1k_prompt_tokens, cost_per_1k_completion_tokens, context_window, enabled)
VALUES
    ('claude-3-5-sonnet-20241022', 'anthropic', 0.003, 0.015, 200000, true),
    ('claude-3-5-haiku-20241022', 'anthropic', 0.0008, 0.004, 200000, true),
    ('gpt-4o', 'openai', 0.005, 0.015, 128000, true),
    ('gpt-4o-mini', 'openai', 0.00015, 0.0006, 128000, true)
ON CONFLICT (name) DO NOTHING;

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(255),
    details JSONB,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource_type ON audit_logs(resource_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
