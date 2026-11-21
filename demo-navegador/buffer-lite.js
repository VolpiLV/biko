// Buffer mínimo (só o que o backend do Biko usa), para rodar no navegador sem o Node.
(function () {
  'use strict';
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  class Buffer extends Uint8Array {
    static from(x, encoding) {
      if (typeof x === 'string') {
        if (encoding === 'hex') {
          const b = new Buffer(x.length >> 1);
          for (let i = 0; i < b.length; i++) b[i] = parseInt(x.substr(i * 2, 2), 16);
          return b;
        }
        if (encoding === 'base64') {
          const bin = atob(x);
          const b = new Buffer(bin.length);
          for (let i = 0; i < bin.length; i++) b[i] = bin.charCodeAt(i);
          return b;
        }
        const u = enc.encode(x);
        const b = new Buffer(u.length); b.set(u); return b;
      }
      if (x instanceof ArrayBuffer) { const u = new Uint8Array(x); const b = new Buffer(u.length); b.set(u); return b; }
      const b = new Buffer(x.length); b.set(x); return b;
    }
    static alloc(n) { return new Buffer(n); }
    static isBuffer(x) { return x instanceof Buffer; }
    static byteLength(s) { return typeof s === 'string' ? enc.encode(s).length : s.length; }
    static concat(list) {
      const total = list.reduce((n, c) => n + c.length, 0);
      const b = new Buffer(total); let off = 0;
      for (const c of list) { b.set(c, off); off += c.length; }
      return b;
    }
    toString(encoding, start = 0, end = this.length) {
      const part = Uint8Array.prototype.subarray.call(this, start, end);
      if (encoding === 'hex') return Array.from(part, (v) => v.toString(16).padStart(2, '0')).join('');
      if (encoding === 'ascii' || encoding === 'latin1') return String.fromCharCode.apply(null, Array.from(part));
      if (encoding === 'base64') { let s = ''; for (const v of part) s += String.fromCharCode(v); return btoa(s); }
      return dec.decode(part);
    }
  }
  window.__BikoBuffer = Buffer;
})();
