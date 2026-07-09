import React, { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import {
  Shield,
  Users,
  AlertTriangle,
  Ban,
  CheckCircle,
  XCircle,
  LogOut,
  Loader2,
  Search,
  Check,
  FileText,
  DollarSign,
  Eye,
  EyeOff,
  LayoutDashboard,
  RefreshCw,
  FolderOpen
} from 'lucide-react';

// Configure Supabase client using credentials from root .env
const SUPABASE_URL = 'https://crpbikhjolxdtluqlqkz.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_SdY_IDJI56WuWcM-ngSZzQ_qQ2QQ-__';
const API_BASE_URL = 'http://localhost:3000';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

type ActiveTab = 'dashboard' | 'kyc' | 'users' | 'listings' | 'disputes';

export default function App() {
  const [session, setSession] = useState<any>(null);
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [authLoading, setAuthLoading] = useState<boolean>(true);
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [authError, setAuthError] = useState<string>('');
  
  // Navigation & Data
  const [activeTab, setActiveTab] = useState<ActiveTab>('dashboard');
  const [stats, setStats] = useState<any>(null);
  const [pendingKyc, setPendingKyc] = useState<any[]>([]);
  const [users, setUsers] = useState<any[]>([]);
  const [listings, setListings] = useState<any[]>([]);
  const [disputes, setDisputes] = useState<any>({ disputedBookings: [], userReports: [] });
  const [loading, setLoading] = useState<boolean>(false);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [rejectNotes, setRejectNotes] = useState<string>('');
  const [selectedUserForReject, setSelectedUserForReject] = useState<string | null>(null);

  // Monitor Auth Session
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      handleSession(session);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      handleSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  const handleSession = async (currentSession: any) => {
    setSession(currentSession);
    if (currentSession) {
      // Validate role from profiles table
      try {
        setAuthLoading(true);
        const { data: profile, error } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', currentSession.user.id)
          .single();

        if (error || !profile || profile.role !== 'admin') {
          setIsAdmin(false);
        } else {
          setIsAdmin(true);
          fetchData();
        }
      } catch (err) {
        setIsAdmin(false);
      } finally {
        setAuthLoading(false);
      }
    } else {
      setIsAdmin(null);
      setAuthLoading(false);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthLoading(true);
    setAuthError('');
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
    } catch (err: any) {
      setAuthError(err.message || 'Login failed. Please check your credentials.');
      setAuthLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
  };

  // Fetch administrative data from NestJS backend endpoints
  const fetchData = async () => {
    const sessionData = await supabase.auth.getSession();
    const token = sessionData.data.session?.access_token;
    if (!token) return;

    setLoading(true);
    try {
      // Stats API
      const statsRes = await fetch(`${API_BASE_URL}/admin/stats`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (statsRes.ok) setStats(await statsRes.json());

      // Pending KYC API
      const kycRes = await fetch(`${API_BASE_URL}/admin/kyc`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (kycRes.ok) setPendingKyc(await kycRes.json());

      // Users API
      const usersRes = await fetch(`${API_BASE_URL}/admin/users`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (usersRes.ok) setUsers(await usersRes.json());

      // Listings API
      const listingsRes = await fetch(`${API_BASE_URL}/admin/listings`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (listingsRes.ok) setListings(await listingsRes.json());

      // Disputes API
      const disputesRes = await fetch(`${API_BASE_URL}/admin/disputes`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (disputesRes.ok) setDisputes(await disputesRes.json());
    } catch (err) {
      console.error('API fetch failed:', err);
    } finally {
      setLoading(false);
    }
  };

  // Refresh current tab data
  useEffect(() => {
    if (isAdmin) {
      fetchData();
    }
  }, [activeTab]);

  // Moderation Handlers
  const handleApproveKyc = async (profileId: string) => {
    const token = session?.access_token;
    if (!token) return;

    if (!confirm('Are you sure you want to verify and approve this user\'s KYC?')) return;

    try {
      const res = await fetch(`${API_BASE_URL}/admin/kyc/${profileId}/approve`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        alert('KYC Verified successfully!');
        fetchData();
      } else {
        alert('Failed to approve KYC');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleRejectKyc = async (e: React.FormEvent) => {
    e.preventDefault();
    const token = session?.access_token;
    if (!token || !selectedUserForReject) return;

    try {
      const res = await fetch(`${API_BASE_URL}/admin/kyc/${selectedUserForReject}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({ notes: rejectNotes })
      });
      if (res.ok) {
        alert('KYC Rejected.');
        setSelectedUserForReject(null);
        setRejectNotes('');
        fetchData();
      } else {
        alert('Failed to reject KYC');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleToggleBan = async (profileId: string) => {
    const token = session?.access_token;
    if (!token) return;

    if (!confirm('Are you sure you want to toggle this user\'s suspension state?')) return;

    try {
      const res = await fetch(`${API_BASE_URL}/admin/users/${profileId}/ban`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        alert(data.message);
        fetchData();
      } else {
        alert('Failed to toggle ban status');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleToggleListing = async (listingId: string) => {
    const token = session?.access_token;
    if (!token) return;

    try {
      const res = await fetch(`${API_BASE_URL}/admin/listings/${listingId}/toggle-visibility`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        alert(data.message);
        fetchData();
      } else {
        alert('Failed to toggle listing visibility');
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleResolveDispute = async (bookingId: string, resolution: 'release' | 'refund') => {
    const token = session?.access_token;
    if (!token) return;

    if (!confirm(`Are you sure you want to resolve this dispute by choosing ${resolution === 'release' ? 'Release Escrow' : 'Refund Renter'}?`)) return;

    try {
      const res = await fetch(`${API_BASE_URL}/admin/disputes/${bookingId}/resolve`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({ resolution })
      });
      if (res.ok) {
        const data = await res.json();
        alert(data.message);
        fetchData();
      } else {
        alert('Failed to resolve dispute');
      }
    } catch (err) {
      console.error(err);
    }
  };

  // Auth Loading screen
  if (authLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-[#08090d]">
        <div className="text-center">
          <Loader2 className="h-12 w-12 animate-spin text-[#a855f7] mx-auto mb-4" />
          <p className="text-[#94a3b8] font-medium">Authorizing Secure Session...</p>
        </div>
      </div>
    );
  }

  // Not Logged In screen
  if (!session) {
    return (
      <div className="flex h-screen items-center justify-center bg-[#08090d] px-4">
        <div className="glass-panel w-full max-w-md p-8 relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-[3px] bg-gradient-to-r from-[#a855f7] to-[#06b6d4]"></div>
          <div className="flex items-center justify-center gap-2 mb-6">
            <div className="bg-[#a855f7]/15 p-3 rounded-2xl border border-[#a855f7]/30">
              <Shield className="h-8 w-8 text-[#a855f7]" />
            </div>
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-white mb-0" style={{ fontSize: '24px', margin: 0 }}>
                SkipIt Admin
              </h1>
              <p className="text-xs text-[#94a3b8]">Production Marketplace Control</p>
            </div>
          </div>

          <form onSubmit={handleLogin} className="flex flex-col gap-4 mt-4">
            {authError && (
              <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-3 text-sm text-[#ef4444] flex items-center gap-2">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>{authError}</span>
              </div>
            )}
            <div className="flex flex-col gap-1 text-left">
              <label className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider pl-1">Admin Email</label>
              <input
                type="email"
                required
                className="glass-input"
                placeholder="admin@skipit.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="flex flex-col gap-1 text-left">
              <label className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider pl-1">Password</label>
              <input
                type="password"
                required
                className="glass-input"
                placeholder="••••••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <button type="submit" className="glow-button w-full mt-2 py-3.5">
              Secure Sign In
            </button>
          </form>
        </div>
      </div>
    );
  }

  // Unauthorized User Screen
  if (isAdmin === false) {
    return (
      <div className="flex h-screen items-center justify-center bg-[#08090d] px-4">
        <div className="glass-panel w-full max-w-md p-8 text-center border-red-500/30">
          <AlertTriangle className="h-16 w-16 text-[#ef4444] mx-auto mb-4" />
          <h2 className="text-xl font-bold text-white mb-2">Access Denied</h2>
          <p className="text-[#94a3b8] text-sm mb-6">
            Your credentials belong to a standard profile. Only certified administrator profiles can bypass platform controls.
          </p>
          <button onClick={handleLogout} className="glow-button bg-none border border-red-500/40 text-white flex items-center justify-center gap-2 mx-auto">
            <LogOut className="h-4 w-4" />
            <span>Sign Out</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-[#08090d] text-white">
      {/* Sidebar Navigation */}
      <aside className="w-64 border-r border-white/5 bg-[#0a0c14] shrink-0 p-6 flex flex-col gap-6">
        <div className="flex items-center gap-3">
          <div className="bg-[#a855f7]/15 p-2 rounded-xl border border-[#a855f7]/30">
            <Shield className="h-6 w-6 text-[#a855f7]" />
          </div>
          <div>
            <h2 className="text-base font-bold text-white mb-0" style={{ margin: 0 }}>SkipIt HQ</h2>
            <p className="text-[10px] text-[#06b6d4] font-semibold uppercase tracking-widest">Admin Portal</p>
          </div>
        </div>

        <nav className="flex flex-col gap-1.5 flex-1 mt-4">
          <button
            onClick={() => setActiveTab('dashboard')}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl font-medium text-sm transition-all duration-200 ${
              activeTab === 'dashboard'
                ? 'bg-[#a855f7]/15 text-[#a855f7] border border-[#a855f7]/30'
                : 'text-[#94a3b8] hover:text-white hover:bg-white/5'
            }`}
          >
            <LayoutDashboard className="h-4 w-4" />
            <span>Dashboard</span>
          </button>

          <button
            onClick={() => setActiveTab('kyc')}
            className={`flex items-center justify-between px-4 py-3 rounded-xl font-medium text-sm transition-all duration-200 ${
              activeTab === 'kyc'
                ? 'bg-[#a855f7]/15 text-[#a855f7] border border-[#a855f7]/30'
                : 'text-[#94a3b8] hover:text-white hover:bg-white/5'
            }`}
          >
            <div className="flex items-center gap-3">
              <CheckCircle className="h-4 w-4" />
              <span>KYC Verification</span>
            </div>
            {pendingKyc.length > 0 && (
              <span className="bg-[#a855f7] text-white text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0">
                {pendingKyc.length}
              </span>
            )}
          </button>

          <button
            onClick={() => setActiveTab('users')}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl font-medium text-sm transition-all duration-200 ${
              activeTab === 'users'
                ? 'bg-[#a855f7]/15 text-[#a855f7] border border-[#a855f7]/30'
                : 'text-[#94a3b8] hover:text-white hover:bg-white/5'
            }`}
          >
            <Users className="h-4 w-4" />
            <span>User Management</span>
          </button>

          <button
            onClick={() => setActiveTab('listings')}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl font-medium text-sm transition-all duration-200 ${
              activeTab === 'listings'
                ? 'bg-[#a855f7]/15 text-[#a855f7] border border-[#a855f7]/30'
                : 'text-[#94a3b8] hover:text-white hover:bg-white/5'
            }`}
          >
            <FolderOpen className="h-4 w-4" />
            <span>Listings Moderator</span>
          </button>

          <button
            onClick={() => setActiveTab('disputes')}
            className={`flex items-center justify-between px-4 py-3 rounded-xl font-medium text-sm transition-all duration-200 ${
              activeTab === 'disputes'
                ? 'bg-[#a855f7]/15 text-[#a855f7] border border-[#a855f7]/30'
                : 'text-[#94a3b8] hover:text-white hover:bg-white/5'
            }`}
          >
            <div className="flex items-center gap-3">
              <AlertTriangle className="h-4 w-4" />
              <span>Disputes & Reports</span>
            </div>
            {(disputes.disputedBookings.length > 0 || disputes.userReports.length > 0) && (
              <span className="bg-[#ef4444] text-white text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0">
                {disputes.disputedBookings.length + disputes.userReports.length}
              </span>
            )}
          </button>
        </nav>

        <div className="mt-auto border-t border-white/5 pt-4">
          <div className="flex items-center gap-3 mb-4 pl-2">
            <div className="bg-[#06b6d4]/10 h-8 w-8 rounded-full border border-[#06b6d4]/30 flex items-center justify-center font-bold text-xs text-[#06b6d4]">
              AD
            </div>
            <div className="overflow-hidden">
              <p className="text-xs font-semibold text-white truncate">{session?.user?.email}</p>
              <p className="text-[10px] text-[#94a3b8] truncate">Active Administrator</p>
            </div>
          </div>

          <button onClick={handleLogout} className="secondary-button w-full py-2.5 flex items-center justify-center gap-2 border-red-500/20 hover:border-red-500/40 text-[#ef4444]">
            <LogOut className="h-4 w-4" />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 p-8 flex flex-col gap-6 overflow-y-auto max-h-screen">
        <header className="flex justify-between items-center pb-4 border-b border-white/5">
          <div>
            <h1 className="text-2xl font-bold tracking-tight mb-0" style={{ fontSize: '26px', margin: 0 }}>
              {activeTab === 'dashboard' && 'Marketplace Overview'}
              {activeTab === 'kyc' && 'KYC Verification Panel'}
              {activeTab === 'users' && 'User Directory & Moderation'}
              {activeTab === 'listings' && 'Inventory Moderation'}
              {activeTab === 'disputes' && 'Dispute Resolution Hub'}
            </h1>
            <p className="text-xs text-[#94a3b8] mt-1">
              Real-time synchronization with SkipIt P2P engine.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button onClick={fetchData} disabled={loading} className="secondary-button p-2.5 rounded-xl shrink-0">
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin text-[#a855f7]' : ''}`} />
            </button>
            <div className="badge badge-success flex items-center gap-1.5 py-1.5 px-3">
              <span className="h-2 w-2 rounded-full bg-[#10b981] animate-pulse"></span>
              <span>API Gateway Connected</span>
            </div>
          </div>
        </header>

        {/* LOADING SHIMMER */}
        {loading && !stats && (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="h-8 w-8 animate-spin text-[#a855f7] mr-2" />
            <span className="text-[#94a3b8]">Fetching ledger state...</span>
          </div>
        )}

        {/* 1. DASHBOARD TAB */}
        {activeTab === 'dashboard' && stats && (
          <div className="flex flex-col gap-8">
            {/* Metric KPI Grid */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-5">
              <div className="glass-panel p-6 flex flex-col gap-1.5 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-5 shrink-0">
                  <Users className="h-16 w-16 text-white" />
                </div>
                <span className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider">Total Users</span>
                <span className="text-3xl font-extrabold text-white">{stats.users.total}</span>
                <div className="text-[10px] text-[#94a3b8] mt-2 flex gap-3">
                  <span>Admins: {stats.users.admins}</span>
                  <span className="text-[#ef4444]">Banned: {stats.users.banned}</span>
                </div>
              </div>

              <div className="glass-panel p-6 flex flex-col gap-1.5 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-5 shrink-0">
                  <FolderOpen className="h-16 w-16 text-white" />
                </div>
                <span className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider">Marketplace Listings</span>
                <span className="text-3xl font-extrabold text-white">{stats.listings.total}</span>
                <div className="text-[10px] text-[#94a3b8] mt-2 flex gap-3">
                  <span className="text-[#10b981]">Active Rent: {stats.listings.active}</span>
                  <span>Hidden: {stats.listings.inactive}</span>
                </div>
              </div>

              <div className="glass-panel p-6 flex flex-col gap-1.5 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-5 shrink-0">
                  <FileText className="h-16 w-16 text-white" />
                </div>
                <span className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider">Completed Bookings</span>
                <span className="text-3xl font-extrabold text-white">{stats.bookings.statuses.completed || 0}</span>
                <div className="text-[10px] text-[#94a3b8] mt-2 flex gap-3">
                  <span>Disputed: {stats.bookings.disputed}</span>
                  <span>Total Contracts: {stats.bookings.total}</span>
                </div>
              </div>

              <div className="glass-panel p-6 flex flex-col gap-1.5 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-5 shrink-0">
                  <DollarSign className="h-16 w-16 text-white" />
                </div>
                <span className="text-xs font-semibold text-[#94a3b8] uppercase tracking-wider">Total Revenue Processed</span>
                <span className="text-3xl font-extrabold text-[#06b6d4]">
                  ₹{(stats.finance.totalRevenueProcessed || 0).toLocaleString()}
                </span>
                <div className="text-[10px] text-[#94a3b8] mt-2 flex gap-3">
                  <span className="text-[#a855f7]">Escrow Hold: ₹{(stats.finance.escrowHoldings || 0).toLocaleString()}</span>
                </div>
              </div>
            </div>

            {/* Sub grids */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Category distribution */}
              <div className="glass-panel p-6 md:col-span-1 flex flex-col gap-4">
                <h3 className="text-base font-bold text-white mb-2">Listing Category Density</h3>
                <div className="flex flex-col gap-3 flex-1">
                  {Object.entries(stats.listings.categories || {}).length === 0 ? (
                    <p className="text-sm text-[#94a3b8] text-center my-auto">No category data</p>
                  ) : (
                    Object.entries(stats.listings.categories).map(([cat, count]: [string, any]) => (
                      <div key={cat} className="flex flex-col gap-1">
                        <div className="flex justify-between text-xs font-medium">
                          <span className="capitalize">{cat}</span>
                          <span className="text-[#a855f7]">{count}</span>
                        </div>
                        <div className="w-full bg-white/5 h-2 rounded-full overflow-hidden">
                          <div
                            className="bg-gradient-to-r from-[#a855f7] to-[#06b6d4] h-full"
                            style={{
                              width: `${((count as number) / stats.listings.total) * 100}%`
                            }}
                          ></div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Booking contract logs */}
              <div className="glass-panel p-6 md:col-span-2 flex flex-col gap-4">
                <h3 className="text-base font-bold text-white mb-2">Escrow Contracts Allocation</h3>
                <div className="grid grid-cols-2 gap-4 flex-1">
                  {Object.entries(stats.bookings.statuses || {}).map(([status, count]: [string, any]) => (
                    <div key={status} className="flex justify-between items-center p-3 rounded-xl bg-white/5 border border-white/5">
                      <div className="flex items-center gap-2">
                        <span
                          className={`h-2.5 w-2.5 rounded-full ${
                            status === 'completed'
                              ? 'bg-[#10b981]'
                              : status === 'disputed'
                              ? 'bg-[#ef4444]'
                              : status === 'paid' || status === 'active'
                              ? 'bg-[#3b82f6]'
                              : 'bg-[#f59e0b]'
                          }`}
                        ></span>
                        <span className="text-xs font-semibold capitalize text-white">{status}</span>
                      </div>
                      <span className="text-sm font-bold text-[#94a3b8]">{count}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* 2. KYC VERIFICATION TAB */}
        {activeTab === 'kyc' && (
          <div className="flex flex-col gap-4">
            {pendingKyc.length === 0 ? (
              <div className="glass-panel p-16 text-center">
                <CheckCircle className="h-12 w-12 text-[#10b981] mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-1">Clear Ledger</h3>
                <p className="text-sm text-[#94a3b8]">All submitted customer identity files have been moderated.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-6">
                {pendingKyc.map((user) => (
                  <div key={user.id} className="glass-panel p-6 flex flex-col md:flex-row gap-6 relative">
                    <div className="flex-1 flex flex-col gap-4">
                      <div className="flex items-center gap-3">
                        <div className="h-10 w-10 bg-[#a855f7]/10 rounded-full flex items-center justify-center font-bold text-[#a855f7] border border-[#a855f7]/25">
                          {user.full_name?.charAt(0) || 'U'}
                        </div>
                        <div>
                          <h3 className="text-base font-bold text-white">{user.full_name}</h3>
                          <p className="text-xs text-[#94a3b8]">{user.phone || 'No phone'}</p>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-4 p-4 rounded-xl bg-white/5 border border-white/5">
                        <div className="flex flex-col text-left">
                          <span className="text-[10px] text-[#94a3b8] uppercase font-semibold">Document Type</span>
                          <span className="text-sm font-bold text-white">{user.kyc_document_type || 'Unspecified'}</span>
                        </div>
                        <div className="flex flex-col text-left">
                          <span className="text-[10px] text-[#94a3b8] uppercase font-semibold">Verification Status</span>
                          <span className="badge badge-warning w-max mt-1">{user.kyc_status}</span>
                        </div>
                      </div>

                      <div className="flex gap-3 mt-auto pt-4">
                        <button
                          onClick={() => handleApproveKyc(user.id)}
                          className="glow-button py-2.5 px-6 text-sm"
                        >
                          <Check className="h-4 w-4" />
                          <span>Approve & Verify</span>
                        </button>
                        <button
                          onClick={() => setSelectedUserForReject(user.id)}
                          className="secondary-button border-red-500/20 text-[#ef4444] hover:bg-red-500/10 py-2.5 px-6 text-sm"
                        >
                          <XCircle className="h-4 w-4" />
                          <span>Reject Submission</span>
                        </button>
                      </div>
                    </div>

                    {/* Document Preview Image */}
                    <div className="w-full md:w-80 h-48 rounded-xl bg-black/40 border border-white/5 overflow-hidden relative group shrink-0 flex items-center justify-center">
                      {user.kyc_document_url ? (
                        <>
                          <img
                            src={user.kyc_document_url}
                            alt="KYC Document Preview"
                            className="w-full h-full object-cover opacity-70 group-hover:scale-105 transition-transform duration-300"
                          />
                          <a
                            href={user.kyc_document_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="absolute bg-black/60 backdrop-blur-md border border-white/10 px-3 py-1.5 rounded-lg text-xs font-semibold text-white flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                            <Eye className="h-3.5 w-3.5" />
                            <span>View Original</span>
                          </a>
                        </>
                      ) : (
                        <div className="text-center p-4">
                          <FileText className="h-8 w-8 text-[#94a3b8] mx-auto mb-2" />
                          <span className="text-xs text-[#94a3b8]">No uploaded document image found</span>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 3. USER MANAGEMENT TAB */}
        {activeTab === 'users' && (
          <div className="flex flex-col gap-6">
            <div className="flex gap-3">
              <div className="relative flex-1">
                <Search className="absolute left-4 top-3.5 h-4 w-4 text-[#94a3b8]" />
                <input
                  type="text"
                  placeholder="Search user profile names, emails, phones..."
                  className="glass-input w-full pl-12"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
            </div>

            <div className="glass-panel overflow-hidden">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-white/5 text-[10px] text-[#94a3b8] uppercase font-bold tracking-wider bg-white/[0.02]">
                    <th className="p-4">Customer Details</th>
                    <th className="p-4">Role</th>
                    <th className="p-4">KYC State</th>
                    <th className="p-4">Trust Score</th>
                    <th className="p-4">Total Rentals</th>
                    <th className="p-4 text-right">Moderation Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                  {users
                    .filter((u) => u.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) || u.phone?.toLowerCase().includes(searchTerm.toLowerCase()))
                    .map((user) => (
                      <tr key={user.id} className="hover:bg-white/[0.01] transition-colors">
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="h-8 w-8 bg-[#06b6d4]/10 rounded-full flex items-center justify-center font-bold text-xs text-[#06b6d4]">
                              {user.full_name?.charAt(0) || 'U'}
                            </div>
                            <div>
                              <p className="text-sm font-semibold text-white">{user.full_name || 'Anonymous User'}</p>
                              <p className="text-xs text-[#94a3b8]">{user.phone || 'No Phone Record'}</p>
                            </div>
                          </div>
                        </td>
                        <td className="p-4">
                          <span className={`text-xs font-semibold capitalize ${user.role === 'admin' ? 'text-[#a855f7]' : 'text-[#94a3b8]'}`}>
                            {user.role}
                          </span>
                        </td>
                        <td className="p-4">
                          <span
                            className={`badge ${
                              user.kyc_status === 'approved'
                                ? 'badge-success'
                                : user.kyc_status === 'pending'
                                ? 'badge-warning'
                                : 'badge-danger'
                            }`}
                          >
                            {user.kyc_status}
                          </span>
                        </td>
                        <td className="p-4">
                          <span className="text-sm font-bold text-white">{user.trust_score || 50}%</span>
                        </td>
                        <td className="p-4">
                          <span className="text-sm font-medium text-white">{user.total_rentals || 0} items</span>
                        </td>
                        <td className="p-4 text-right">
                          <button
                            onClick={() => handleToggleBan(user.id)}
                            className={`secondary-button py-1.5 px-3.5 text-xs inline-flex items-center gap-1.5 ${
                              user.is_banned ? 'bg-red-500/20 text-[#ef4444] border-red-500/30' : ''
                            }`}
                          >
                            <Ban className="h-3 w-3" />
                            <span>{user.is_banned ? 'Banned' : 'Suspend User'}</span>
                          </button>
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* 4. LISTINGS MODERATION TAB */}
        {activeTab === 'listings' && (
          <div className="flex flex-col gap-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {listings.map((listing) => (
                <div key={listing.id} className="glass-panel overflow-hidden flex flex-col">
                  <div className="h-44 bg-black/40 relative">
                    {listing.images && listing.images.length > 0 ? (
                      <img
                        src={listing.images[0]}
                        alt="Listing Cover"
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <FolderOpen className="h-10 w-10 text-[#94a3b8]" />
                      </div>
                    )}
                    <span className="absolute top-3 left-3 bg-black/60 backdrop-blur-md border border-white/10 px-2 py-0.5 rounded-md text-[10px] uppercase font-bold text-[#06b6d4]">
                      {listing.category}
                    </span>
                  </div>

                  <div className="p-5 flex flex-col gap-3 flex-1">
                    <div>
                      <h3 className="text-base font-bold text-white leading-tight truncate">{listing.title}</h3>
                      <p className="text-xs text-[#94a3b8] mt-1 line-clamp-2">{listing.description}</p>
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-left bg-white/5 border border-white/5 p-3 rounded-xl mt-1">
                      <div className="flex flex-col">
                        <span className="text-[8px] text-[#94a3b8] uppercase font-semibold">Rent Per Day</span>
                        <span className="text-xs font-bold text-white">₹{listing.price_per_day}</span>
                      </div>
                      <div className="flex flex-col">
                        <span className="text-[8px] text-[#94a3b8] uppercase font-semibold">Deposit Sec</span>
                        <span className="text-xs font-bold text-white">₹{listing.deposit_amount}</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between border-t border-white/5 pt-4 mt-auto">
                      <div className="flex flex-col text-left">
                        <span className="text-[9px] text-[#94a3b8]">Owner Listing</span>
                        <span className="text-xs font-semibold text-white truncate max-w-[120px]">
                          {listing.profiles?.full_name || 'System'}
                        </span>
                      </div>

                      <button
                        onClick={() => handleToggleListing(listing.id)}
                        className={`secondary-button py-1.5 px-3 text-xs inline-flex items-center gap-1.5 ${
                          !listing.is_available ? 'bg-red-500/10 border-red-500/30 text-[#ef4444]' : 'bg-green-500/10 border-green-500/30 text-[#10b981]'
                        }`}
                      >
                        {listing.is_available ? <Eye className="h-3.5 w-3.5" /> : <EyeOff className="h-3.5 w-3.5" />}
                        <span>{listing.is_available ? 'Live' : 'Deactivated'}</span>
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 5. DISPUTES & REPORTS TAB */}
        {activeTab === 'disputes' && (
          <div className="flex flex-col gap-6">
            <h3 className="text-lg font-bold text-white mb-1">Open Disputed Rental Contracts</h3>
            {disputes.disputedBookings.length === 0 ? (
              <div className="glass-panel p-10 text-center mb-6">
                <CheckCircle className="h-10 w-10 text-[#10b981] mx-auto mb-2" />
                <p className="text-sm text-[#94a3b8]">No current bookings have open disputes or holding claims.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4 mb-6">
                {disputes.disputedBookings.map((booking: any) => (
                  <div key={booking.id} className="glass-panel p-5 flex flex-col md:flex-row justify-between gap-4">
                    <div className="flex flex-col gap-2 text-left">
                      <div className="flex items-center gap-2">
                        <span className="badge badge-danger">Disputed Booking</span>
                        <span className="text-xs text-[#94a3b8]">ID: {booking.id}</span>
                      </div>
                      <h4 className="text-base font-bold text-white mt-1">Listing: {booking.listing?.title}</h4>
                      <p className="text-xs text-[#94a3b8]">
                        Owner: <span className="text-white font-medium">{booking.listing?.profiles?.full_name}</span> | 
                        Renter: <span className="text-white font-medium">{booking.renter?.full_name}</span>
                      </p>
                      <p className="text-xs text-[#94a3b8] mt-1">
                        Contract Ledger: Rent total <span className="text-white font-medium">₹{booking.total_price}</span> | 
                        Deposit held <span className="text-white font-medium">₹{booking.deposit_paid}</span>
                      </p>
                    </div>

                    <div className="flex items-center gap-2.5 mt-auto md:mt-0 shrink-0">
                      <button
                        onClick={() => handleResolveDispute(booking.id, 'release')}
                        className="glow-button py-2 px-4 text-xs font-semibold bg-green-500"
                        style={{ background: 'var(--status-success)' }}
                      >
                        <Check className="h-3.5 w-3.5" />
                        <span>Release Payout</span>
                      </button>
                      <button
                        onClick={() => handleResolveDispute(booking.id, 'refund')}
                        className="secondary-button border-red-500/20 text-[#ef4444] hover:bg-red-500/10 py-2 px-4 text-xs"
                      >
                        <XCircle className="h-3.5 w-3.5" />
                        <span>Refund Renter</span>
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <h3 className="text-lg font-bold text-white mb-1">Customer Incident Reports</h3>
            {disputes.userReports.length === 0 ? (
              <div className="glass-panel p-10 text-center">
                <CheckCircle className="h-10 w-10 text-[#10b981] mx-auto mb-2" />
                <p className="text-sm text-[#94a3b8]">Clear incidents directory: no new customer support reports.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4">
                {disputes.userReports.map((report: any) => (
                  <div key={report.id} className="glass-panel p-5 text-left flex flex-col gap-3">
                    <div className="flex justify-between items-center">
                      <span className="badge badge-info">Report ID: {report.id}</span>
                      <span className="text-xs text-[#94a3b8]">{new Date(report.created_at).toLocaleDateString()}</span>
                    </div>

                    <div className="flex flex-col gap-1.5">
                      <h4 className="text-sm font-bold text-white">Reason: {report.reason}</h4>
                      <p className="text-xs text-[#94a3b8] leading-relaxed bg-black/20 p-3 rounded-lg border border-white/5">
                        {report.description || 'No detailed incident description provided.'}
                      </p>
                    </div>

                    <div className="flex flex-wrap gap-x-6 gap-y-2 pt-2 border-t border-white/5 text-[11px] text-[#94a3b8]">
                      <span>Reporter: <strong className="text-white">{report.reporter?.full_name || 'Anonymous'}</strong></span>
                      {report.reported_user && <span>Reported: <strong className="text-white">{report.reported_user?.full_name}</strong></span>}
                      {report.listing && <span>Listing: <strong className="text-white">{report.listing?.title}</strong></span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>

      {/* Reject KYC Modal Sheet */}
      {selectedUserForReject && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-md p-4">
          <div className="glass-panel w-full max-w-md p-6 relative">
            <h3 className="text-lg font-bold text-white mb-2">Reject KYC Submission</h3>
            <p className="text-xs text-[#94a3b8] mb-4">
              Provide specific reviewer notes explaining to the customer why their identity verification failed (e.g. Blurry photo, mismatched names).
            </p>

            <form onSubmit={handleRejectKyc} className="flex flex-col gap-4">
              <textarea
                required
                className="glass-input h-28 resize-none py-3"
                placeholder="Reviewer notes..."
                value={rejectNotes}
                onChange={(e) => setRejectNotes(e.target.value)}
              ></textarea>

              <div className="flex gap-3 justify-end mt-2">
                <button
                  type="button"
                  onClick={() => {
                    setSelectedUserForReject(null);
                    setRejectNotes('');
                  }}
                  className="secondary-button py-2 px-4 text-sm"
                >
                  Cancel
                </button>
                <button type="submit" className="glow-button bg-red-600 py-2 px-4 text-sm" style={{ background: 'var(--status-error)' }}>
                  Confirm Rejection
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
