import Razorpay from "npm:razorpay";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {

  // handle preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {

    const { amount, receipt } = await req.json();

    const razorpay = new Razorpay({
      key_id: Deno.env.get("RAZORPAY_KEY_ID"),
      key_secret: Deno.env.get("RAZORPAY_KEY_SECRET"),
    });

    const order = await razorpay.orders.create({
      amount,
      currency: "INR",
      receipt
    });

    return new Response(
      JSON.stringify(order),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        }
      }
    );

  } catch (error) {

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        }
      }
    );

  }

});