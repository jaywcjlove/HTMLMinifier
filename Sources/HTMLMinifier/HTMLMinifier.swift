import JavaScriptCore
import Foundation

/// HTML minification options
public struct HTMLMinifierOptions: Sendable {
    public let removeAttributeQuotes: Bool
    public let removeComments: Bool
    public let removeEmptyAttributes: Bool
    public let removeRedundantAttributes: Bool
    public let removeScriptTypeAttributes: Bool
    public let removeStyleLinkTypeAttributes: Bool
    public let trimCustomFragments: Bool
    public let useShortDoctype: Bool
    public let collapseWhitespace: Bool
    public let conservativeCollapse: Bool
    public let preserveLineBreaks: Bool
    public let collapseBooleanAttributes: Bool
    public let removeEmptyElements: Bool
    public let minifyJS: Bool
    public let minifyCSS: Bool
    public let minifyURLs: Bool
    
    public init(
        removeAttributeQuotes: Bool = false,
        removeComments: Bool = false,
        removeEmptyAttributes: Bool = false,
        removeRedundantAttributes: Bool = false,
        removeScriptTypeAttributes: Bool = false,
        removeStyleLinkTypeAttributes: Bool = false,
        trimCustomFragments: Bool = false,
        useShortDoctype: Bool = false,
        collapseWhitespace: Bool = false,
        conservativeCollapse: Bool = false,
        preserveLineBreaks: Bool = false,
        collapseBooleanAttributes: Bool = false,
        removeEmptyElements: Bool = false,
        minifyJS: Bool = false,
        minifyCSS: Bool = false,
        minifyURLs: Bool = false
    ) {
        self.removeAttributeQuotes = removeAttributeQuotes
        self.removeComments = removeComments
        self.removeEmptyAttributes = removeEmptyAttributes
        self.removeRedundantAttributes = removeRedundantAttributes
        self.removeScriptTypeAttributes = removeScriptTypeAttributes
        self.removeStyleLinkTypeAttributes = removeStyleLinkTypeAttributes
        self.trimCustomFragments = trimCustomFragments
        self.useShortDoctype = useShortDoctype
        self.collapseWhitespace = collapseWhitespace
        self.conservativeCollapse = conservativeCollapse
        self.preserveLineBreaks = preserveLineBreaks
        self.collapseBooleanAttributes = collapseBooleanAttributes
        self.removeEmptyElements = removeEmptyElements
        self.minifyJS = minifyJS
        self.minifyCSS = minifyCSS
        self.minifyURLs = minifyURLs
    }
}

/// HTML Minifier error types
public enum HTMLMinifierError: Error {
    case jsContextCreationFailed
    case jsScriptLoadFailed(String)
    case minificationFailed(String)
    case invalidInput
}

/// HTML Minifier class that wraps the JavaScript html-minifier library
public class HTMLMinifier {
    private let jsContext: JSContext
    
    /// Initialize HTMLMinifier
    public init() throws {
        guard let jsContext = JSContext() else {
            throw HTMLMinifierError.jsContextCreationFailed
        }
        self.jsContext = jsContext
        
        // Set up exception handler
        jsContext.exceptionHandler = { context, exception in
            print("JS Exception: \(exception?.toString() ?? "Unknown error")")
        }
        
        try loadHTMLMinifierScript()
    }
    
    /// Load the html-minifier JavaScript bundle
    private func loadHTMLMinifierScript() throws {
        guard let bundlePath = Bundle.module.path(forResource: "htmlminifier.umd.bundle.min", ofType: "js"),
              let scriptContent = try? String(contentsOfFile: bundlePath, encoding: .utf8) else {
            throw HTMLMinifierError.jsScriptLoadFailed("Could not load htmlminifier.umd.bundle.min.js")
        }
        
        // Provide browser environment polyfills
        jsContext.evaluateScript("""
            var window = this;
            var document = {};
            var location = { host: 'localhost' };
            var XMLHttpRequest = function() {
                this.open = function(method, url) {};
                this.send = function() {};
                this.setRequestHeader = function() {};
                this.getResponseHeader = function() { return ''; };
                this.overrideMimeType = function() {};
                this.readyState = 4;
                this.status = 200;
                this.responseText = '';
            };
            var global = this;
        """)
        
        // Prepare the UMD loading environment
        jsContext.evaluateScript("var HTMLMinifier = {};")
        
        jsContext.evaluateScript(scriptContent)
        
        // Check if HTMLMinifier is available and has minify function
        let htmlMinifier = jsContext.objectForKeyedSubscript("HTMLMinifier")
        if htmlMinifier?.isUndefined != false {
            throw HTMLMinifierError.jsScriptLoadFailed("HTMLMinifier library not found in global scope")
        }
        
        // Check if minify function exists
        let minifyFunction = htmlMinifier?.objectForKeyedSubscript("minify")
        let hasMinify = minifyFunction?.isUndefined == false
        
        let defaultExport = htmlMinifier?.objectForKeyedSubscript("default")
        let defaultMinifyFunction = defaultExport?.objectForKeyedSubscript("minify")
        let hasDefaultMinify = defaultMinifyFunction?.isUndefined == false
        
        if !hasMinify && !hasDefaultMinify {
            throw HTMLMinifierError.jsScriptLoadFailed("minify function not found in HTMLMinifier")
        }
    }
    
    /// Minify HTML string with given options
    /// - Parameters:
    ///   - html: The HTML string to minify
    ///   - options: Minification options
    /// - Returns: Minified HTML string
    /// - Throws: HTMLMinifierError if minification fails
    public func minify(_ html: String, options: HTMLMinifierOptions = HTMLMinifierOptions()) throws -> String {
        guard !html.isEmpty else {
            throw HTMLMinifierError.invalidInput
        }
        
        // Convert options to JavaScript object
        let optionsDict: [String: Any] = [
            "removeAttributeQuotes": options.removeAttributeQuotes,
            "removeComments": options.removeComments,
            "removeEmptyAttributes": options.removeEmptyAttributes,
            "removeRedundantAttributes": options.removeRedundantAttributes,
            "removeScriptTypeAttributes": options.removeScriptTypeAttributes,
            "removeStyleLinkTypeAttributes": options.removeStyleLinkTypeAttributes,
            "trimCustomFragments": options.trimCustomFragments,
            "useShortDoctype": options.useShortDoctype,
            "collapseWhitespace": options.collapseWhitespace,
            "conservativeCollapse": options.conservativeCollapse,
            "preserveLineBreaks": options.preserveLineBreaks,
            "collapseBooleanAttributes": options.collapseBooleanAttributes,
            "removeEmptyElements": options.removeEmptyElements,
            "minifyJS": options.minifyJS,
            "minifyCSS": options.minifyCSS,
            "minifyURLs": options.minifyURLs
        ]
        
        // Call the minify function
        guard let htmlMinifier = jsContext.objectForKeyedSubscript("HTMLMinifier") else {
            throw HTMLMinifierError.minificationFailed("HTMLMinifier object not found")
        }
        
        // In the UMD bundle, the minify function is exported as HTMLMinifier.minify or HTMLMinifier.default.minify
        var minifyFunction = htmlMinifier.objectForKeyedSubscript("minify")
        
        if minifyFunction?.isUndefined != false {
            // Try to get it from the default export
            if let defaultExport = htmlMinifier.objectForKeyedSubscript("default") {
                minifyFunction = defaultExport.objectForKeyedSubscript("minify")
            }
        }
        
        guard let minify = minifyFunction, minify.isUndefined == false else {
            throw HTMLMinifierError.minificationFailed("minify function not found in HTMLMinifier")
        }
        
        // The minify function returns a Promise, so we need to handle it properly
        // We'll create a synchronous wrapper using a while loop
        jsContext.evaluateScript("""
            window.__promiseResult = null;
            window.__promiseError = null;
            window.__promiseComplete = false;
        """)
        
        let callResult = minify.call(withArguments: [html, optionsDict])
        
        // Set up promise resolution
        jsContext.evaluateScript("""
            (function(promise) {
                promise.then(function(result) {
                    window.__promiseResult = result;
                    window.__promiseComplete = true;
                }).catch(function(error) {
                    window.__promiseError = error.toString();
                    window.__promiseComplete = true;
                });
            })
        """).call(withArguments: [callResult as Any])
        
        // Wait for completion with timeout
        let startTime = Date()
        let timeout: TimeInterval = 10.0
        
        while !jsContext.evaluateScript("window.__promiseComplete")!.toBool() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw HTMLMinifierError.minificationFailed("Minification timed out")
            }
            Thread.sleep(forTimeInterval: 0.01) // 10ms polling
        }
        
        // Check for errors
        if let error = jsContext.evaluateScript("window.__promiseError"), !error.isNull && !error.isUndefined {
            throw HTMLMinifierError.minificationFailed("Minification error: \(error.toString() ?? "Unknown error")")
        }
        
        // Get the result
        guard let resultValue = jsContext.evaluateScript("window.__promiseResult"),
              !resultValue.isNull && !resultValue.isUndefined,
              let result = resultValue.toString() else {
            throw HTMLMinifierError.minificationFailed("No valid result from minification")
        }
        
        return result
    }
    
    /// Minify HTML string with default options (commonly used settings)
    /// - Parameter html: The HTML string to minify
    /// - Returns: Minified HTML string
    /// - Throws: HTMLMinifierError if minification fails
    public func minify(_ html: String) throws -> String {
        let defaultOptions = HTMLMinifierOptions(
            removeComments: true,
            removeEmptyAttributes: true,
            removeRedundantAttributes: true,
            removeScriptTypeAttributes: true,
            removeStyleLinkTypeAttributes: true,
            useShortDoctype: true,
            collapseWhitespace: true,
            collapseBooleanAttributes: true
        )
        
        return try minify(html, options: defaultOptions)
    }
}

// MARK: - Static convenience methods
extension HTMLMinifier {
    /// Static method to minify HTML with default options
    /// - Parameter html: The HTML string to minify
    /// - Returns: Minified HTML string
    /// - Throws: HTMLMinifierError if minification fails
    public static func minify(_ html: String) throws -> String {
        let minifier = try HTMLMinifier()
        return try minifier.minify(html)
    }
    
    /// Static method to minify HTML with custom options
    /// - Parameters:
    ///   - html: The HTML string to minify
    ///   - options: Minification options
    /// - Returns: Minified HTML string
    /// - Throws: HTMLMinifierError if minification fails
    public static func minify(_ html: String, options: HTMLMinifierOptions) throws -> String {
        let minifier = try HTMLMinifier()
        return try minifier.minify(html, options: options)
    }
}
