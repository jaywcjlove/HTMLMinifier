import Testing
@testable import HTMLMinifier

@Test("Remove attribute quotes")
func removeAttributeQuotes() throws {
    let minifier = try HTMLMinifier()
    let html = #"<p title="blah" id="moo">foo</p>"#
    
    let options = HTMLMinifierOptions(removeAttributeQuotes: true)
    let result = try minifier.minify(html, options: options)
    
    #expect(result == "<p title=blah id=moo>foo</p>")
}

@Test("Remove comments")
func removeComments() throws {
    let minifier = try HTMLMinifier()
    let html = "<p>foo</p><!-- comment --><div>bar</div>"
    
    let options = HTMLMinifierOptions(removeComments: true)
    let result = try minifier.minify(html, options: options)
    
    #expect(result == "<p>foo</p><div>bar</div>")
}

@Test("Collapse whitespace")
func collapseWhitespace() throws {
    let minifier = try HTMLMinifier()
    let html = "<p>  foo   bar  </p>   <div>  baz  </div>"
    
    let options = HTMLMinifierOptions(collapseWhitespace: true)
    let result = try minifier.minify(html, options: options)
    
    #expect(result == "<p>foo bar</p><div>baz</div>")
}

@Test("Default options minification")
func defaultMinification() throws {
    let html = #"<p title="test">  Hello World  </p><!-- comment -->"#
    let option: HTMLMinifierOptions = .init(removeComments: true)
    let result = try HTMLMinifier.minify(html, options: option)
    // Should remove comments, collapse whitespace, etc. based on default options
    #expect(result.contains("Hello World"))
    #expect(!result.contains("comment"))
}

@Test("Use short doctype")
func useShortDoctype() throws {
    let minifier = try HTMLMinifier()
    let html = #"<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html><head><title>Test</title></head><body><p>Hello</p></body></html>"#
    
    let options = HTMLMinifierOptions(useShortDoctype: true)
    let result = try minifier.minify(html, options: options)
    
    // html-minifier uses lowercase for doctype
    #expect(result.hasPrefix("<!doctype html>"))
}
