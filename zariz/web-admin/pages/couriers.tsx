import { withAuth } from '../libs/withAuth';

function Couriers() {
  return (
    <div style={{ padding: 24 }}>
      <h1>Couriers</h1>
      <p>Coming soon in TICKET-19.</p>
    </div>
  );
}

export default withAuth(Couriers);

