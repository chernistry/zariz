import { redirect } from 'next/navigation';

export default async function Dashboard() {
  // Placeholder - auth will be implemented in TICKET-22
  redirect('/dashboard/overview');
}
