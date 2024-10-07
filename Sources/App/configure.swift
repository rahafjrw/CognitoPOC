import Leaf
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.views.use(.leaf)
    
    let awsClient = AWSClient(httpClientProvider: .shared(app.http.client.shared))
    let awsCognitoConfiguration = CognitoConfiguration(
        userPoolId: Environment.get("POOL_ID")!,
        clientId: Environment.get("CLIENT_ID")!,
        clientSecret: Environment.get("CLIENT_SECRET")!,
        cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
        adminClient: true
    )
    app.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
    
    app.sessions.use(.memory)
    
    // Configures cookie value creation.
    app.sessions.configuration.cookieFactory = { sessionID in
            .init(string: sessionID.string, isSecure: true, isHTTPOnly: true)
    }

    app.middleware.use(app.sessions.middleware)
    
    // register routes
    try routes(app)
}
