const handler = require('./api/generate');

// Mock Request (The input data)
const req = {
  method: 'POST',
  body: {
    spec: {
      product_name: 'Test Product',
      description: 'A simple landing page'
    },
    shadow: false
  }
};

// Mock Response (To capture what the handler sends back)
const res = {
  statusCode: 200,
  _json: null,
  status: function(code) {
    this.statusCode = code;
    return this;
  },
  json: function(data) {
    this._json = data;
    console.log('--- STATUS CODE ---');
    console.log(this.statusCode);
    console.log('--- RESPONSE BODY ---');
    console.log(JSON.stringify(data, null, 2));
    return this;
  }
};

// Run the test
console.log('Running test...');
handler(req, res).then(() => {
  console.log('Test complete.');
}).catch(err => {
  console.error('Test crashed:', err);
});
