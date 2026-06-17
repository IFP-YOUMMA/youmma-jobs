import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://slawwbhlakilnviwzyrb.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYXd3YmhsYWtpbG52aXd6eXJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0MjQxODAsImV4cCI6MjA5NjAwMDE4MH0.XgZRkUrkjCUzSlB0Nyp0QdJf4xZjMcTO5V1bKSDUHNg';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export default supabase;
