// supabase/functions/razorpay-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import crypto from "https://deno.land/std@0.177.0/node/crypto.ts";

serve(async (req) => {
  try {
    // Get webhook signature from headers
    const webhookSignature = req.headers.get('x-razorpay-signature');
    const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')!;
    
    // Read raw body for signature verification
    const body = await req.text();
    
    // ✅ VERIFY WEBHOOK SIGNATURE
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(body)
      .digest('hex');

    if (expectedSignature !== webhookSignature) {
      console.error('Invalid webhook signature');
      return new Response('Invalid signature', { status: 401 });
    }

    const payload = JSON.parse(body);
    const event = payload.event;
    const payment = payload.payload.payment.entity;
    const order = payload.payload.order?.entity;

    console.log(`[Webhook] Received event: ${event}`, {
      payment_id: payment.id,
      order_id: order?.id
    });

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // ✅ REPLAY PROTECTION: Check if we've processed this payment
    const { data: existingPayment } = await supabaseClient
      .from('processed_webhooks')
      .select('*')
      .eq('razorpay_payment_id', payment.id)
      .single();

    if (existingPayment) {
      console.log(`[Webhook] Payment ${payment.id} already processed, skipping`);
      return new Response('Already processed', { status: 200 });
    }

    // Handle different webhook events
    switch (event) {
      case 'payment.captured':
      case 'order.paid':
        await handleSuccessfulPayment(payment, order, supabaseClient);
        break;
        
      case 'payment.failed':
        await handleFailedPayment(payment, order, supabaseClient);
        break;
        
      case 'payment.authorized':
        console.log('Payment authorized:', payment.id);
        break;
        
      default:
        console.log(`Unhandled event: ${event}`);
    }

    // Mark as processed (replay protection)
    await supabaseClient
      .from('processed_webhooks')
      .insert({
        razorpay_payment_id: payment.id,
        razorpay_order_id: order?.id,
        event_type: event,
        processed_at: new Date().toISOString()
      });

    return new Response('Webhook processed', { status: 200 });

  } catch (error) {
    console.error('[Webhook] Error:', error);
    return new Response(error.message, { status: 500 });
  }
});

async function handleSuccessfulPayment(payment: any, order: any, supabase: any) {
  console.log('[Webhook] Processing successful payment:', payment.id);

  // Get order reference from receipt
  const orderReference = order?.receipt;
  
  if (!orderReference) {
    console.error('[Webhook] No order reference found');
    return;
  }

  // Check if order already exists
  const { data: existingOrder } = await supabase
    .from('orders')
    .select('id')
    .eq('order_reference', orderReference)
    .single();

  if (existingOrder) {
    console.log('[Webhook] Order already exists:', existingOrder.id);
    
    // Just update payment status if needed
    await supabase
      .from('orders')
      .update({
        payment_status: 'paid',
        razorpay_payment_id: payment.id,
        updated_at: new Date().toISOString()
      })
      .eq('id', existingOrder.id);
    
    return;
  }

  // Order doesn't exist - create it (backup path)
  console.log('[Webhook] Creating order from webhook');
  
  // Get pending order
  const { data: pendingOrder } = await supabase
    .from('pending_orders')
    .select('*')
    .eq('order_reference', orderReference)
    .single();

  if (!pendingOrder) {
    console.error('[Webhook] No pending order found for:', orderReference);
    return;
  }

  // Create order
  const { data: newOrder, error: orderError } = await supabase
    .from('orders')
    .insert({
      user_id: pendingOrder.user_id,
      address_id: pendingOrder.address_id,
      total_amount: pendingOrder.total_amount,
      shipping_cost: pendingOrder.shipping_cost,
      payment_method: 'razorpay',
      payment_status: 'paid',
      order_status: 'confirmed',
      razorpay_payment_id: payment.id,
      razorpay_order_id: order?.id,
      order_reference: orderReference
    })
    .select()
    .single();

  if (orderError) {
    console.error('[Webhook] Error creating order:', orderError);
    return;
  }

  // Add order items
  const orderItems = pendingOrder.cart_items.map((item: any) => ({
    order_id: newOrder.id,
    variant_id: item.variant_id,
    quantity: item.quantity,
    price: item.price
  }));

  await supabase.from('order_items').insert(orderItems);

  // Delete pending order
  await supabase
    .from('pending_orders')
    .delete()
    .eq('order_reference', orderReference);

  // Send confirmation email
  await sendOrderConfirmationEmail(newOrder.id, pendingOrder.user_id);

  console.log('[Webhook] Order created successfully:', newOrder.id);
}

async function handleFailedPayment(payment: any, order: any, supabase: any) {
  console.log('[Webhook] Processing failed payment:', payment.id);

  const orderReference = order?.receipt;

  if (orderReference) {
    await supabase
      .from('pending_orders')
      .update({ 
        status: 'payment_failed',
        failure_reason: payment.error_description,
        updated_at: new Date().toISOString()
      })
      .eq('order_reference', orderReference);

    // Notify user
    await sendPaymentFailureNotification(orderReference, payment.error_description);
  }

  // Log failure
  await supabase
    .from('payment_logs')
    .insert({
      razorpay_payment_id: payment.id,
      razorpay_order_id: order?.id,
      status: 'failed',
      error: payment.error_description,
      created_at: new Date().toISOString()
    });
}