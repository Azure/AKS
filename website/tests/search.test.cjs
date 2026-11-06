const assert = require('node:assert/strict');
const { readFileSync, existsSync } = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { gzipSync } = require('node:zlib');
const lunr = require('@cmfcmf/docusaurus-search-local/lib/lunr.js');

const buildDir = path.resolve(__dirname, '../build');
const raw = readFileSync(path.join(buildDir, 'search-index-default.json'));
const { documents, index: serializedIndex } = JSON.parse(raw);
const index = lunr.Index.load(serializedIndex);
const byId = new Map(documents.map((document) => [String(document.id), document]));
const search = (query) => index.search(query).map((hit) => byId.get(hit.ref));

test('local index stays within the browser download budget', () => {
  assert.ok(raw.length < 4 * 1024 * 1024, 'Index exceeds 4 MiB uncompressed. Reassess local search.');
  assert.ok(gzipSync(raw).length < 1024 * 1024, 'Index exceeds 1 MiB gzipped. Reassess local search.');
});

test('indexes blog titles, full post content, and tags', () => {
  assert.ok(search('title:kaito').some((document) =>
    document.pageTitle === 'Autoscale KAITO inference workloads on AKS using KEDA'));
  assert.ok(search('content:inferenceset').some((document) =>
    document.sectionRoute.startsWith('/2026/02/03/autoscale-inference-workloads-with-kaito#')));
  assert.ok(search('tags:networking').length > 0);
  assert.deepEqual(search('zzzxnonexistentsearchtermxzzz'), []);
});

test('results link to real post pages and section anchors, not listing pages', () => {
  assert.ok(documents.length > 0);
  const pages = new Map();
  for (const document of documents) {
    assert.equal(document.type, 'blog');
    assert.ok(document.pageTitle);
    const [route, anchor] = document.sectionRoute.split('#');
    assert.ok(route.startsWith('/') && !route.startsWith('//'));
    assert.ok(!/^\/(?:tags|authors)(?:\/|$)/.test(route));
    if (!pages.has(route)) {
      const file = path.join(buildDir, `${route}.html`);
      assert.ok(existsSync(file), `Missing result page: ${route}`);
      const html = readFileSync(file, 'utf8');
      const anchors = [...html.matchAll(/\sid=(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g)]
        .map((match) => match[1] ?? match[2] ?? match[3]);
      pages.set(route, new Set(anchors));
    }
    if (anchor) {
      assert.ok(pages.get(route).has(decodeURIComponent(anchor)),
        `Missing result anchor: ${document.sectionRoute}`);
    }
  }
});
