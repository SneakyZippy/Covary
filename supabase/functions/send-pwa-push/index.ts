import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"
import webpush from "https://esm.sh/web-push@3.6.3"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Configure VAPID details (Web Push standards)
// Make sure to add VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY to your Supabase Edge Function Secrets:
// Command: supabase secrets set VAPID_PUBLIC_KEY="your-public-key" VAPID_PRIVATE_KEY="your-private-key"
const VAPID_PUBLIC_KEY = Deno.env.get('VAPID_PUBLIC_KEY')!;
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY')!;
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:researcher@covary.org';

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  // Handle CORS pre-flight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    });
  }

  try {
    const now = new Date().toISOString();
    
    // 1. Query pending unsent push reminders that are due
    const { data: reminders, error: fetchError } = await supabase
      .from('pwa_push_reminders')
      .select('*')
      .eq('sent', false)
      .lte('scheduled_for', now);

    if (fetchError) throw fetchError;
    
    if (!reminders || reminders.length === 0) {
      return new Response(JSON.stringify({ message: "No notifications due." }), {
        headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' },
        status: 200,
      });
    }

    const results = [];
    for (const item of reminders) {
      try {
        // Send the push notification payload to browser push service
        await webpush.sendNotification(
          item.subscription,
          JSON.stringify(item.payload)
        );
        
        // Mark as sent
        await supabase
          .from('pwa_push_reminders')
          .update({ sent: true })
          .eq('id', item.id);

        results.push({ id: item.id, status: 'success' });
      } catch (err) {
        // If browser returns 410 (Gone) or 404 (Not Found), the subscription has expired or was revoked
        if (err.statusCode === 410 || err.statusCode === 404) {
          await supabase.from('pwa_push_reminders').delete().eq('id', item.id);
          results.push({ id: item.id, status: 'deleted_expired_subscription' });
        } else {
          results.push({ id: item.id, status: 'failed', error: err.message });
        }
      }
    }

    return new Response(JSON.stringify({ sent: results }), {
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' },
      status: 500,
    });
  }
});
