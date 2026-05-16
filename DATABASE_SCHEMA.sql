-- OptiWork AI - Complete Database Schema
-- PostgreSQL 15+
-- Last Updated: May 2026

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE role_type AS ENUM ('SUPER_ADMIN', 'ADMIN', 'HR_MANAGER', 'MANAGER', 'EMPLOYEE');
CREATE TYPE attendance_status AS ENUM ('PRESENT', 'ABSENT', 'LATE', 'EARLY_DEPARTURE', 'ON_LEAVE');
CREATE TYPE verification_method AS ENUM ('FACE', 'BIOMETRIC', 'GPS', 'MANUAL', 'COMBINED');
CREATE TYPE payroll_status AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'PROCESSED', 'PAID', 'FAILED');
CREATE TYPE leave_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');
CREATE TYPE enrollment_status AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'EXPIRED');
CREATE TYPE audit_action AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'DOWNLOAD');

-- ============================================================================
-- AUTHENTICATION & USERS
-- ============================================================================

CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    logo_url TEXT,
    website_url TEXT,
    description TEXT,
    industry VARCHAR(100),
    employee_count INTEGER,
    max_employees INTEGER DEFAULT 1000,
    
    -- Subscription
    plan_type VARCHAR(50) DEFAULT 'starter',
    stripe_customer_id VARCHAR(255),
    subscription_status VARCHAR(50) DEFAULT 'active',
    billing_cycle_start DATE,
    billing_cycle_end DATE,
    
    -- Settings
    timezone VARCHAR(50) DEFAULT 'UTC',
    currency VARCHAR(3) DEFAULT 'USD',
    date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD',
    
    -- Metadata
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    CONSTRAINT org_active CHECK (deleted_at IS NULL)
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(20),
    
    -- Authentication
    password_hash VARCHAR(255),
    password_changed_at TIMESTAMP,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP,
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    last_login_at TIMESTAMP,
    last_login_ip VARCHAR(45),
    
    -- Biometric
    biometric_enabled BOOLEAN DEFAULT FALSE,
    biometric_data JSONB,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_locked BOOLEAN DEFAULT FALSE,
    locked_until TIMESTAMP,
    failed_login_attempts INTEGER DEFAULT 0,
    
    -- Metadata
    avatar_url TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    
    CONSTRAINT user_active CHECK (deleted_at IS NULL),
    CONSTRAINT user_email_unique UNIQUE (organization_id, email),
    CONSTRAINT password_or_oauth CHECK (password_hash IS NOT NULL OR biometric_enabled = TRUE)
);

CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role role_type NOT NULL,
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT role_unique UNIQUE (user_id, organization_id, role)
);

CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Device info
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    device_type VARCHAR(50), -- 'mobile', 'web', 'tablet'
    os_type VARCHAR(50),
    os_version VARCHAR(50),
    app_version VARCHAR(20),
    
    -- Session
    access_token_hash VARCHAR(255),
    refresh_token_hash VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    last_activity_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    CONSTRAINT session_unique UNIQUE (user_id, device_id)
);

CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    key_hash VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255),
    description TEXT,
    
    -- Permissions
    permissions TEXT[] DEFAULT ARRAY['read'],
    
    -- Usage
    rate_limit INTEGER DEFAULT 1000,
    last_used_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- ============================================================================
-- ORGANIZATION STRUCTURE
-- ============================================================================

CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50),
    description TEXT,
    manager_id UUID REFERENCES users(id),
    
    parent_department_id UUID REFERENCES departments(id),
    budget DECIMAL(15, 2),
    
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT dept_unique UNIQUE (organization_id, code)
);

CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    zip_code VARCHAR(20),
    
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT location_unique UNIQUE (organization_id, name)
);

CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id),
    
    name VARCHAR(255) NOT NULL,
    description TEXT,
    leader_id UUID REFERENCES users(id),
    
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE employee_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    department_id UUID REFERENCES departments(id),
    team_id UUID REFERENCES teams(id),
    location_id UUID REFERENCES locations(id),
    manager_id UUID REFERENCES users(id),
    
    employee_code VARCHAR(50),
    job_title VARCHAR(255),
    employment_type VARCHAR(50), -- 'full_time', 'part_time', 'contract'
    
    -- Salary info
    monthly_salary DECIMAL(12, 2),
    hourly_rate DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    
    start_date DATE NOT NULL,
    end_date DATE,
    
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT assignment_unique UNIQUE (organization_id, employee_code)
);

-- ============================================================================
-- ATTENDANCE TRACKING
-- ============================================================================

CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES employee_assignments(id),
    
    attendance_date DATE NOT NULL,
    clock_in_time TIMESTAMP,
    clock_out_time TIMESTAMP,
    
    status attendance_status NOT NULL,
    
    -- Verification
    verification_method verification_method,
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP,
    
    -- Location info
    clock_in_latitude DECIMAL(10, 8),
    clock_in_longitude DECIMAL(11, 8),
    clock_out_latitude DECIMAL(10, 8),
    clock_out_longitude DECIMAL(11, 8),
    
    -- Duration
    total_hours DECIMAL(5, 2),
    break_duration INTERVAL,
    
    -- Notes
    notes TEXT,
    exceptions JSONB DEFAULT '{}',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT attendance_unique UNIQUE (user_id, attendance_date)
);

CREATE TABLE geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    location_id UUID REFERENCES locations(id),
    
    name VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 100,
    
    is_enabled BOOLEAN DEFAULT TRUE,
    require_for_attendance BOOLEAN DEFAULT TRUE,
    
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE gps_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(8, 2),
    altitude DECIMAL(10, 2),
    
    device_id VARCHAR(255),
    speed DECIMAL(8, 2),
    heading DECIMAL(6, 2),
    
    is_mock_location BOOLEAN DEFAULT FALSE,
    is_valid BOOLEAN DEFAULT TRUE,
    
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_timestamp (user_id, recorded_at DESC),
    INDEX idx_location (latitude, longitude)
);

CREATE TABLE attendance_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_id UUID NOT NULL REFERENCES attendance_records(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    
    verification_type VARCHAR(50), -- 'face', 'gps', 'biometric'
    confidence_score DECIMAL(5, 4),
    is_passed BOOLEAN,
    
    raw_response JSONB,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- FACIAL RECOGNITION
-- ============================================================================

CREATE TABLE face_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    embedding vector(512),
    embedding_model VARCHAR(50) DEFAULT 'insightface_r100',
    
    face_image_url TEXT,
    quality_score DECIMAL(5, 4),
    
    enrollment_method VARCHAR(50), -- 'mobile_app', 'web', 'admin'
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMP,
    
    status enrollment_status DEFAULT 'PENDING',
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    CONSTRAINT enrollment_unique UNIQUE (user_id, status) WHERE status = 'VERIFIED'
);

CREATE TABLE face_recognition_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    attempt_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    matched_enrollment_id UUID REFERENCES face_enrollments(id),
    
    confidence_score DECIMAL(5, 4),
    is_liveness_passed BOOLEAN,
    liveness_score DECIMAL(5, 4),
    
    image_url TEXT,
    processing_time_ms INTEGER,
    
    matched BOOLEAN DEFAULT FALSE,
    error_message TEXT,
    
    device_info JSONB,
    ip_address VARCHAR(45),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_timestamp (user_id, attempt_timestamp DESC)
);

-- ============================================================================
-- PAYROLL & COMPENSATION
-- ============================================================================

CREATE TABLE salary_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    assignment_id UUID NOT NULL REFERENCES employee_assignments(id),
    
    base_salary DECIMAL(12, 2) NOT NULL,
    hourly_rate DECIMAL(10, 2),
    overtime_multiplier DECIMAL(3, 2) DEFAULT 1.5,
    
    allowances JSONB DEFAULT '{}', -- {housing: 500, transport: 200}
    deductions JSONB DEFAULT '{}', -- {insurance: 100, loan: 50}
    
    effective_from DATE,
    effective_to DATE,
    
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    payroll_month DATE NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    total_employees INTEGER,
    processed_count INTEGER DEFAULT 0,
    
    status payroll_status DEFAULT 'DRAFT',
    
    total_gross_salary DECIMAL(15, 2),
    total_net_salary DECIMAL(15, 2),
    total_deductions DECIMAL(15, 2),
    
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,
    
    processed_at TIMESTAMP,
    processed_by UUID REFERENCES users(id),
    
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT payroll_run_unique UNIQUE (organization_id, payroll_month)
);

CREATE TABLE payroll_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    assignment_id UUID REFERENCES employee_assignments(id),
    
    -- Components
    base_salary DECIMAL(12, 2),
    overtime_hours DECIMAL(6, 2),
    overtime_pay DECIMAL(12, 2),
    bonuses DECIMAL(12, 2),
    allowances DECIMAL(12, 2),
    
    -- Deductions
    tax_deduction DECIMAL(12, 2),
    insurance_deduction DECIMAL(12, 2),
    loan_deduction DECIMAL(12, 2),
    other_deductions DECIMAL(12, 2),
    
    -- Totals
    gross_salary DECIMAL(12, 2),
    total_deductions DECIMAL(12, 2),
    net_salary DECIMAL(12, 2),
    
    -- Attendance impact
    absent_days DECIMAL(5, 2),
    late_arrivals INTEGER,
    early_departures INTEGER,
    
    -- Status
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP,
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payslips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_detail_id UUID NOT NULL REFERENCES payroll_details(id),
    user_id UUID NOT NULL REFERENCES users(id),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    
    payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id),
    
    pdf_url TEXT,
    generated_at TIMESTAMP,
    
    viewed_by_employee BOOLEAN DEFAULT FALSE,
    viewed_at TIMESTAMP,
    
    payment_method VARCHAR(50), -- 'bank_transfer', 'check', 'cash'
    payment_reference VARCHAR(255),
    paid_at TIMESTAMP,
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- LEAVE MANAGEMENT
-- ============================================================================

CREATE TABLE leave_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    leave_type VARCHAR(50), -- 'annual', 'sick', 'personal'
    year INTEGER,
    
    total_days DECIMAL(5, 2),
    used_days DECIMAL(5, 2) DEFAULT 0,
    pending_days DECIMAL(5, 2) DEFAULT 0,
    
    carry_forward_days DECIMAL(5, 2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT leave_balance_unique UNIQUE (user_id, leave_type, year)
);

CREATE TABLE leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    leave_type VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days DECIMAL(5, 2),
    
    reason TEXT,
    attachment_url TEXT,
    
    status leave_status DEFAULT 'PENDING',
    
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ANALYTICS & PRODUCTIVITY
-- ============================================================================

CREATE TABLE productivity_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    metric_date DATE NOT NULL,
    
    -- Scores
    productivity_score DECIMAL(5, 4),
    attendance_reliability DECIMAL(5, 4),
    shift_efficiency DECIMAL(5, 4),
    task_completion_rate DECIMAL(5, 4),
    consistency_index DECIMAL(5, 4),
    
    -- Metrics
    actual_hours DECIMAL(8, 2),
    scheduled_hours DECIMAL(8, 2),
    overtime_hours DECIMAL(8, 2),
    tasks_completed INTEGER,
    tasks_assigned INTEGER,
    
    -- Burnout indicators
    consecutive_days_worked INTEGER,
    excess_overtime_hours DECIMAL(8, 2),
    burnout_risk_level VARCHAR(50), -- 'low', 'medium', 'high'
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT productivity_unique UNIQUE (user_id, metric_date)
);

CREATE TABLE ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    
    insight_type VARCHAR(100), -- 'understaffing_prediction', 'burnout_risk', etc.
    title VARCHAR(255),
    description TEXT,
    
    confidence_score DECIMAL(5, 4),
    recommendations TEXT[],
    
    is_actionable BOOLEAN DEFAULT TRUE,
    
    dismissed_at TIMESTAMP,
    acted_upon_at TIMESTAMP,
    
    data JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE TABLE department_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    metric_date DATE NOT NULL,
    
    total_employees INTEGER,
    present_employees INTEGER,
    absent_employees INTEGER,
    on_leave_employees INTEGER,
    
    avg_productivity_score DECIMAL(5, 4),
    avg_attendance_rate DECIMAL(5, 4),
    total_overtime_hours DECIMAL(10, 2),
    
    efficiency_index DECIMAL(5, 4),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT dept_metrics_unique UNIQUE (department_id, metric_date)
);

-- ============================================================================
-- NOTIFICATIONS & COMMUNICATION
-- ============================================================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50), -- 'attendance', 'payroll', 'alert', 'info'
    
    icon_url TEXT,
    action_url TEXT,
    action_type VARCHAR(50),
    
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    INDEX idx_user_unread (user_id, is_read)
);

-- ============================================================================
-- AUDIT & COMPLIANCE
-- ============================================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    
    action audit_action NOT NULL,
    resource_type VARCHAR(50), -- 'user', 'attendance', 'payroll'
    resource_id UUID,
    
    old_values JSONB,
    new_values JSONB,
    changes JSONB,
    
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_info JSONB,
    
    status VARCHAR(50) DEFAULT 'success',
    error_message TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_org_timestamp (organization_id, created_at DESC),
    INDEX idx_user_timestamp (user_id, created_at DESC),
    INDEX idx_resource (resource_type, resource_id)
);

-- ============================================================================
-- FILE MANAGEMENT
-- ============================================================================

CREATE TABLE file_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50),
    file_size BIGINT,
    s3_key TEXT NOT NULL,
    s3_url TEXT,
    
    upload_type VARCHAR(50), -- 'face_image', 'document', 'report'
    related_id UUID,
    
    is_virus_scanned BOOLEAN DEFAULT FALSE,
    virus_scan_result VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- ============================================================================
-- SYSTEM CONFIGURATION
-- ============================================================================

CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    setting_key VARCHAR(255) NOT NULL,
    setting_value JSONB,
    setting_type VARCHAR(50), -- 'string', 'number', 'boolean', 'json'
    
    description TEXT,
    is_editable BOOLEAN DEFAULT TRUE,
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(id),
    
    CONSTRAINT system_settings_unique UNIQUE (organization_id, setting_key)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- User indexes
CREATE INDEX idx_users_org_email ON users(organization_id, email);
CREATE INDEX idx_users_active ON users(is_active, deleted_at);
CREATE INDEX idx_user_roles_org ON user_roles(organization_id, role);

-- Attendance indexes
CREATE INDEX idx_attendance_user_date ON attendance_records(user_id, attendance_date DESC);
CREATE INDEX idx_attendance_org_date ON attendance_records(organization_id, attendance_date DESC);
CREATE INDEX idx_attendance_status ON attendance_records(status);

-- GPS indexes
CREATE INDEX idx_gps_user_time ON gps_locations(user_id, recorded_at DESC);
CREATE INDEX idx_gps_location_spatial ON gps_locations USING GIST (ll_to_earth(latitude, longitude));

-- Face enrollment indexes
CREATE INDEX idx_face_enrollment_user ON face_enrollments(user_id, status);
CREATE INDEX idx_face_embedding ON face_enrollments USING IVFFLAT (embedding vector_cosine_ops) 
    WITH (lists = 100) WHERE status = 'VERIFIED';

-- Metrics indexes
CREATE INDEX idx_productivity_user_date ON productivity_metrics(user_id, metric_date DESC);
CREATE INDEX idx_insights_org_date ON ai_insights(organization_id, created_at DESC);
CREATE INDEX idx_department_metrics_date ON department_metrics(department_id, metric_date DESC);

-- Payroll indexes
CREATE INDEX idx_payroll_details_run ON payroll_details(payroll_run_id);
CREATE INDEX idx_payroll_user_run ON payroll_details(user_id, payroll_run_id);

-- Audit indexes
CREATE INDEX idx_audit_org_date ON audit_logs(organization_id, created_at DESC);
CREATE INDEX idx_audit_user_date ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);

-- ============================================================================
-- MATERIALIZED VIEWS FOR ANALYTICS
-- ============================================================================

CREATE MATERIALIZED VIEW daily_attendance_summary AS
SELECT
    organization_id,
    attendance_date,
    COUNT(*) as total_records,
    COUNT(CASE WHEN status = 'PRESENT' THEN 1 END) as present_count,
    COUNT(CASE WHEN status = 'ABSENT' THEN 1 END) as absent_count,
    COUNT(CASE WHEN status = 'LATE' THEN 1 END) as late_count,
    COUNT(CASE WHEN status = 'ON_LEAVE' THEN 1 END) as leave_count,
    AVG(EXTRACT(EPOCH FROM (clock_out_time - clock_in_time)) / 3600) as avg_hours
FROM attendance_records
WHERE deleted_at IS NULL
GROUP BY organization_id, attendance_date;

CREATE MATERIALIZED VIEW employee_monthly_stats AS
SELECT
    user_id,
    organization_id,
    DATE_TRUNC('month', attendance_date)::DATE as month,
    COUNT(*) as total_days,
    COUNT(CASE WHEN status = 'PRESENT' THEN 1 END) as present_days,
    COUNT(CASE WHEN status = 'ABSENT' THEN 1 END) as absent_days,
    COUNT(CASE WHEN status = 'LATE' THEN 1 END) as late_days,
    SUM(EXTRACT(EPOCH FROM (clock_out_time - clock_in_time)) / 3600) as total_hours
FROM attendance_records
WHERE deleted_at IS NULL
GROUP BY user_id, organization_id, DATE_TRUNC('month', attendance_date);

-- ============================================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_records_updated_at BEFORE UPDATE ON attendance_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payroll_runs_updated_at BEFORE UPDATE ON payroll_runs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- GRANTS & SECURITY
-- ============================================================================

-- Create readonly user for analytics
CREATE USER optiwork_readonly WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE optiwork TO optiwork_readonly;
GRANT USAGE ON SCHEMA public TO optiwork_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO optiwork_readonly;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA public TO optiwork_readonly;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE attendance_records IS 'Core attendance tracking with status and verification method';
COMMENT ON TABLE face_enrollments IS 'Face embeddings for facial recognition, one verified per user';
COMMENT ON TABLE gps_locations IS 'Real-time GPS location tracking for geofencing and route tracking';
COMMENT ON TABLE productivity_metrics IS 'Daily productivity scores and metrics';
COMMENT ON TABLE ai_insights IS 'AI-generated insights and predictions';
COMMENT ON COLUMN face_enrollments.embedding IS 'Face embedding vector (512-dim) from InsightFace R100';
COMMENT ON COLUMN gps_locations.is_mock_location IS 'Flag for potential GPS spoofing detection';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
