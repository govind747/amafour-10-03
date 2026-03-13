/*
  # Update Cart and Orders System

  1. New Tables
    - Update cart_items to include product details
    - Add shipping_details to orders
    - Add payment_details to orders
    - Add order tracking information

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users

  3. Changes
    - Add shiprocket integration fields
    - Add razorpay payment fields
    - Update order status workflow
*/

-- Update cart_items table to include more product details
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cart_items' AND column_name = 'product_name'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN product_name text;
    ALTER TABLE cart_items ADD COLUMN product_image text;
    ALTER TABLE cart_items ADD COLUMN variant_weight numeric;
    ALTER TABLE cart_items ADD COLUMN variant_weight_unit text;
  END IF;
END $$;

-- Update orders table for shipping and payment
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_method'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_method text DEFAULT 'standard';
    ALTER TABLE orders ADD COLUMN shipping_cost numeric DEFAULT 0;
    ALTER TABLE orders ADD COLUMN shiprocket_order_id text;
    ALTER TABLE orders ADD COLUMN shiprocket_shipment_id text;
    ALTER TABLE orders ADD COLUMN tracking_number text;
    ALTER TABLE orders ADD COLUMN razorpay_order_id text;
    ALTER TABLE orders ADD COLUMN razorpay_payment_id text;
    ALTER TABLE orders ADD COLUMN payment_method text;
    ALTER TABLE orders ADD COLUMN estimated_delivery_date date;
  END IF;
END $$;

-- Create order_tracking table
CREATE TABLE IF NOT EXISTS order_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  status text NOT NULL,
  message text,
  location text,
  timestamp timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own order tracking"
  ON order_tracking
  FOR SELECT
  TO authenticated
  USING (order_id IN (
    SELECT id FROM orders 
    WHERE user_id IN (
      SELECT id FROM users WHERE auth_id = uid()
    )
  ));