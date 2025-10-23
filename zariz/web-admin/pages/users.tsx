import { withAuth } from '../libs/withAuth';

function Users() {
  return (
    <div style={{ padding: 24 }}>
      <h1>Users</h1>
      <p>Coming soon in TICKET-19.</p>
    </div>
  );
}

export default withAuth(Users);

