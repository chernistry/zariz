def test_openapi_schema(client):
    r = client.get('/openapi.json')
    assert r.status_code == 200
    data = r.json()
    assert data['info']['title'] == 'Zariz API'

