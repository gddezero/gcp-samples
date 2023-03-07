function transform(inJson) {
  var obj = JSON.parse(inJson);
  var tick = {
    "event_name": obj.e,
    "event_time": obj.t,
    "symbol": obj.s,
    "first_update_id": obj.i,
    "final_update_id": obj.l,
    "bids": {"price": parseFloat(obj.b[0]), "quantity": parseInt(obj.b[1])},
    "asks": {"price": parseFloat(obj.a[0]), "quantity": parseInt(obj.a[1])},
    "dt": new Date(obj.t * 1000).toISOString().slice(0, 10)
  };

  return JSON.stringify(tick);
}