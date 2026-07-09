'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://slawwbhlakilnviwzyrb.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYXd3YmhsYWtpbG52aXd6eXJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTcwMDAwMDAsImV4cCI6MjAzMjU2MDAwMH0.example'
);

export default function ArtisansPage() {
  const [providers, setProviders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchProviders() {
      const { data } = await supabase.from('providers').select('*').limit(12);
      setProviders(data || []);
      setLoading(false);
    }
    fetchProviders();
  }, []);

  return (
    <div style={{ backgroundColor: '#0a0f2e', minHeight: '100vh', color: 'white', padding: '32px' }}>
      <h1 style={{ fontSize: '36px', fontWeight: 'bold', textAlign: 'center', marginBottom: '32px' }}>
        Nos <span style={{ color: '#f97316' }}>Artisans</span>
      </h1>
      {loading ? (
        <p style={{ textAlign: 'center' }}>Chargement...</p>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '24px' }}>
          {providers.map((p: any) => (
            <div key={p.id} style={{ backgroundColor: 'white', borderRadius: '16px', overflow: 'hidden' }}>
              <div style={{ backgroundColor: '#0d1340', padding: '24px', textAlign: 'center' }}>
                <div style={{ width: '80px', height: '80px', borderRadius: '50%', backgroundColor: '#f97316', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '28px', fontWeight: 'bold', color: 'white', margin: '0 auto 12px' }}>
                  {p.prenom?.[0]}{p.nom?.[0]}
                </div>
                <h3 style={{ color: 'white', fontWeight: 'bold', fontSize: '18px', margin: '0 0 4px' }}>{p.prenom} {p.nom}</h3>
                <p style={{ color: '#f97316', fontSize: '14px', margin: '0 0 8px' }}>{p.metier}</p>
                <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: '13px', margin: 0 }}>📍 {p.localisation}</p>
              </div>
              <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <a href={`https://wa.me/${p.telephone}`} target="_blank" style={{ flex: 1, backgroundColor: '#25d366', color: 'white', padding: '10px', borderRadius: '8px', textAlign: 'center', textDecoration: 'none', fontSize: '13px', fontWeight: 'bold' }}>📱 WhatsApp</a>
                  <a href={`tel:${p.telephone}`} style={{ flex: 1, backgroundColor: '#f3f4f6', color: '#0d1340', padding: '10px', borderRadius: '8px', textAlign: 'center', textDecoration: 'none', fontSize: '13px', fontWeight: 'bold' }}>📞 Appeler</a>
                </div>
                <Link href={`/artisans/${p.id}`} style={{ backgroundColor: '#0d1340', color: 'white', padding: '10px', borderRadius: '8px', textAlign: 'center', textDecoration: 'none', fontSize: '13px', fontWeight: 'bold', display: 'block' }}>👤 Voir le profil</Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
