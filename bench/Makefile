all: docs

docs: README.md

README.md: README.org
	pandoc --from org --to gfm <$< >$@

TOPO=--size 52
TOPO+=--loc EU --loc AP --loc US
TOPO+=--topology-output topology.json.
TOPO+=--dot-output       topology.dot

topology:
	./make-topology.hs ${TOPO}
	jq '.' topology.json. > topology.json && rm topology.json.
	neato -s120 -Tpdf topology.dot > topology.pdf
	evince topology.pdf
