def test_sse_stream_opens_and_closes(client):
    # Request a single-chunk SSE response for deterministic testing
    r = client.get("/v1/events/sse?once=1")
    assert r.status_code == 200
    body = r.content.decode()
    assert ":ok" in body
