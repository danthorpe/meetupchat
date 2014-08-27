all: cocoa
cocoa: cocoa_protocol

cocoa_protocol: gen-cocoa/protocol.h

gen-cocoa/%.h: %.thrift
	thrift --gen cocoa:validated $<