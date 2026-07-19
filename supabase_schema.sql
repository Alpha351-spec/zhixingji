-- ============================================================
-- 知行计 - Supabase 数据库建表脚本
-- 在 Supabase Dashboard → SQL Editor 中执行此脚本
-- ============================================================

-- 1. 用户表
CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY,
  nickname TEXT,
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 学习计划表
CREATE TABLE IF NOT EXISTS plans (
  plan_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  goal TEXT NOT NULL,
  diagnosis_json TEXT NOT NULL,
  tasks_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  deadline TEXT NOT NULL DEFAULT '',
  total_days INTEGER NOT NULL DEFAULT 0,
  current_week INTEGER NOT NULL DEFAULT 1
);

-- 3. 任务表
CREATE TABLE IF NOT EXISTS tasks (
  task_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plan_id BIGINT NOT NULL REFERENCES plans(plan_id) ON DELETE CASCADE,
  day INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  resource_keywords TEXT DEFAULT '',
  encouragement TEXT DEFAULT '',
  completed INTEGER NOT NULL DEFAULT 0,
  focus_minutes INTEGER NOT NULL DEFAULT 0,
  verification_type TEXT DEFAULT 'none'
);

-- 4. 打卡记录表
CREATE TABLE IF NOT EXISTS checkins (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  plan_id BIGINT NOT NULL REFERENCES plans(plan_id) ON DELETE CASCADE,
  task_id BIGINT NOT NULL REFERENCES tasks(task_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. 验证记录表
CREATE TABLE IF NOT EXISTS verification_records (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  task_id BIGINT,
  task_day INTEGER NOT NULL,
  plan_id INTEGER NOT NULL,
  verification_type TEXT NOT NULL,
  questions_json TEXT,
  user_answer TEXT,
  ai_evaluation TEXT,
  passed INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

-- 6. 用户设置表
CREATE TABLE IF NOT EXISTS user_settings (
  user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  settings_json JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- RLS（行级安全）策略
-- 当前使用 anon key 直接访问，后续接入正式登录后需启用 RLS
-- ============================================================

-- 启用 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- 开发阶段：允许匿名访问（生产环境需改为按用户 ID 过滤）
CREATE POLICY "Allow all for anon" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON plans FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON checkins FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON verification_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON user_settings FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 索引（提升查询性能）
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_plans_user_id ON plans(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_plan_id ON tasks(plan_id);
CREATE INDEX IF NOT EXISTS idx_checkins_user_plan ON checkins(user_id, plan_id);
CREATE INDEX IF NOT EXISTS idx_verification_user ON verification_records(user_id);

-- ============================================================
-- 权限授权（关键！确保 anon 角色可操作所有表）
-- Supabase 默认启用了 RLS，但新项目需要显式授权
-- ============================================================

-- 方式一：通过 RLS 策略（已在上方设置）
-- 方式二：直接授权 anon 角色（更可靠，推荐开发阶段使用）
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon;
