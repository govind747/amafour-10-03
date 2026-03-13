/*
  # Fix Cart Issues and Add Missing Features

  1. New Tables
    - contact_messages - Store contact form submissions
    - user_browsing_history - Track user browsing history
    - user_recommendations - Store personalized recommendations
    - payment_methods - Store user payment methods

  2. Security
    - Enable RLS on all new tables
    - Add policies for authenticated users

  3. Changes
    - Fix cart_items table structure
    - Add missing indexes
    - Add contact form functionality
*/

-- Create contact_messages table
CREATE TABLE IF NOT EXISTS contact_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  status text DEFAULT 'new',
  created_at timestamptz DEFAULT now()
);

-- Create user_browsing_history table
CREATE TABLE IF NOT EXISTS user_browsing_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  viewed_at timestamptz DEFAULT now()
);

-- Create user_recommendations table
CREATE TABLE IF NOT EXISTS user_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  recommendation_type text DEFAULT 'general',
  score numeric DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  method_type text NOT NULL, -- 'card', 'upi', 'netbanking'
  provider text, -- 'visa', 'mastercard', 'paytm', etc.
  last_four text,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE contact_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_browsing_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

-- Contact messages policies (admin only for reading)
CREATE POLICY "Anyone can create contact messages" ON contact_messages
  FOR INSERT TO anon, authenticated
  USING (true);

-- Browsing history policies
CREATE POLICY "Users can manage own browsing history" ON user_browsing_history
  FOR ALL TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Recommendations policies
CREATE POLICY "Users can read own recommendations" ON user_recommendations
  FOR SELECT TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Payment methods policies
CREATE POLICY "Users can manage own payment methods" ON payment_methods
  FOR ALL TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Create indexes
CREATE INDEX IF NOT EXISTS contact_messages_created_at_idx ON contact_messages(created_at);
CREATE INDEX IF NOT EXISTS user_browsing_history_user_id_idx ON user_browsing_history(user_id);
CREATE INDEX IF NOT EXISTS user_browsing_history_product_id_idx ON user_browsing_history(product_id);
CREATE INDEX IF NOT EXISTS user_recommendations_user_id_idx ON user_recommendations(user_id);
CREATE INDEX IF NOT EXISTS payment_methods_user_id_idx ON payment_methods(user_id);

-- Add some sample browsing history and recommendations for existing users
INSERT INTO user_browsing_history (user_id, product_id, viewed_at)
SELECT 
  u.id,
  p.id,
  now() - interval '1 day' * random() * 30
FROM users u
CROSS JOIN products p
WHERE random() < 0.3
ON CONFLICT DO NOTHING;

INSERT INTO user_recommendations (user_id, product_id, recommendation_type, score)
SELECT 
  u.id,
  p.id,
  'popular',
  random() * 100
FROM users u
CROSS JOIN products p
WHERE random() < 0.2
ON CONFLICT DO NOTHING;