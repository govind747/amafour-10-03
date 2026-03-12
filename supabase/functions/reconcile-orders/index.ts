// supabase/functions/reconcile-orders/index.ts
// Run every hour via cron job
serve(async () => {
  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  // Find pending orders older than 30 minutes with successful payments
  const { data: staleOrders } = await supabaseClient
    .from('pending_orders')
    .select('*')
    .lt('expires_at', new Date().toISOString())
    .eq('status', 'pending_payment');

  for (const order of staleOrders || []) {
    try {
      // Check with Razorpay API
      const razorpay = new Razorpay({
        key_id: Deno.env.get("RAZORPAY_KEY_ID")!,
        key_secret: Deno.env.get("RAZORPAY_KEY_SECRET")!,
      });

      const razorpayOrder = await razorpay.orders.fetch(order.razorpay_order_id);
      
      if (razorpayOrder.status === 'paid') {
        // Payment succeeded but no webhook/frontend update
        await createOrderFromPending(order, supabaseClient);
        
        await supabaseClient
          .from('payment_audit_log')
          .insert({
            order_reference: order.order_reference,
            event_type: 'order_reconciled',
            source: 'cron',
            event_data: { reason: 'stale_pending_with_paid_status' }
          });
      }
    } catch (error) {
      console.error('Reconciliation error:', error);
    }
  }
});