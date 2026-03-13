/*
  # Fix uid() function and add review features

  1. New Tables
    - Fix the uid() function reference
    - Add review_likes table for user likes on reviews
    - Add review_comments table for comments on reviews
    - Update order tracking policies

  2. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
    - Fix existing policies with correct auth function

  3. Changes
    - Replace uid() with auth.uid()
    - Add review interaction features
    - Add wishlist functionality
*/

-- Fix the order_tracking policy with correct auth function
DROP POLICY IF EXISTS "Users can read own order tracking" ON order_tracking;

CREATE POLICY "Users can read own order tracking"
  ON order_tracking
  FOR SELECT
  TO authenticated
  USING (order_id IN (
    SELECT id FROM orders 
    WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  ));

-- Create review_likes table
CREATE TABLE IF NOT EXISTS review_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Create review_comments table
CREATE TABLE IF NOT EXISTS review_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  comment text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create wishlist table
CREATE TABLE IF NOT EXISTS wishlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, product_id)
);

-- Enable RLS
ALTER TABLE review_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- Review likes policies
CREATE POLICY "Anyone can read review likes" ON review_likes
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Users can manage own review likes" ON review_likes
  FOR ALL TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Review comments policies
CREATE POLICY "Anyone can read review comments" ON review_comments
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "Users can create review comments" ON review_comments
  FOR INSERT TO authenticated
  WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can update own review comments" ON review_comments
  FOR UPDATE TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can delete own review comments" ON review_comments
  FOR DELETE TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Wishlist policies
CREATE POLICY "Users can manage own wishlist" ON wishlist
  FOR ALL TO authenticated
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Create indexes
CREATE INDEX IF NOT EXISTS review_likes_review_id_idx ON review_likes(review_id);
CREATE INDEX IF NOT EXISTS review_likes_user_id_idx ON review_likes(user_id);
CREATE INDEX IF NOT EXISTS review_comments_review_id_idx ON review_comments(review_id);
CREATE INDEX IF NOT EXISTS review_comments_user_id_idx ON review_comments(user_id);
CREATE INDEX IF NOT EXISTS wishlist_user_id_idx ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS wishlist_product_id_idx ON wishlist(product_id);