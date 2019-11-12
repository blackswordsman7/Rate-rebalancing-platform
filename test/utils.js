const expectRevert = require('@openzeppelin/test-helpers/src/expectRevert');

module.exports.waitForEvent = (_event, _from = 0, _to = 'latest') =>
  new Promise((resolve, reject) =>
    _event({ fromBlock: _from, toBlock: _to }, (e, ev) =>
      e ? reject(e) : resolve(ev)))

module.exports.expectRevert = _method =>
  expectRevert.unspecified(_method)
