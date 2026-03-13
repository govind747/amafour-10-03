/*
  # Fix order_tracking table and related issues

  1. New Tables
    - Ensure order_tracking table exists with correct structure
    - Add missing columns to existing tables if needed
    - Fix all function references to use auth.uid()

  2. Security
    - Enable RLS on all tables
    - Add proper policies for order_tracking
    - Fix existing policies with correct auth function

  3. Changes
    - Replace any remaining uid() with auth.uid()
    - Add review interaction features
    - Add wishlist functionality
    - Ensure all tables have proper structure
*/

-- Ensure order_tracking table exists
CREATE TABLE IF NOT EXISTS order_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  status text NOT NULL,
  message text,
  location text,
  timestamp timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Update cart_items table to include more product details if columns don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cart_items' AND column_name = 'product_name'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN product_name text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cart_items' AND column_name = 'product_image'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN product_image text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cart_items' AND column_name = 'variant_weight'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN variant_weight numeric;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cart_items' AND column_name = 'variant_weight_unit'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN variant_weight_unit text;
  END IF;
END $$;

-- Update orders table for shipping and payment if columns don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_method'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_method text DEFAULT 'standard';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_cost'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_cost numeric DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shiprocket_order_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN shiprocket_order_id text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shiprocket_shipment_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN shiprocket_shipment_id text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'tracking_number'
  ) THEN
    ALTER TABLE orders ADD COLUMN tracking_number text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'razorpay_order_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN razorpay_order_id text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'razorpay_payment_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN razorpay_payment_id text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'payment_method'
  ) THEN
    ALTER TABLE orders ADD COLUMN payment_method text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'estimated_delivery_date'
  ) THEN
    ALTER TABLE orders ADD COLUMN estimated_delivery_date date;
  END IF;
END $$;

-- Create review_likes table if it doesn't exist
CREATE TABLE IF NOT EXISTS review_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Create review_comments table if it doesn't exist
CREATE TABLE IF NOT EXISTS review_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  comment text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create wishlist table if it doesn't exist
CREATE TABLE IF NOT EXISTS wishlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, product_id)
);

-- Enable RLS on all tables
ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- Drop existing policies that might have uid() function
DROP POLICY IF EXISTS "Users can read own order tracking" ON order_tracking;

-- Create correct policies with auth.uid()
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

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS order_tracking_order_id_idx ON order_tracking(order_id);
CREATE INDEX IF NOT EXISTS review_likes_review_id_idx ON review_likes(review_id);
CREATE INDEX IF NOT EXISTS review_likes_user_id_idx ON review_likes(user_id);
CREATE INDEX IF NOT EXISTS review_comments_review_id_idx ON review_comments(review_id);
CREATE INDEX IF NOT EXISTS review_comments_user_id_idx ON review_comments(user_id);
CREATE INDEX IF NOT EXISTS wishlist_user_id_idx ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS wishlist_product_id_idx ON wishlist(product_id);