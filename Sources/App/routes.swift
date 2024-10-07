import Vapor
import NIO
import SotoCognitoAuthentication
import SotoCognitoAuthenticationKit
import SotoCognitoIdentityProvider
import SotoCognitoIdentity


func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("home", ["title": "Home"])
    }
    
    app.middleware.use(LoggingMiddleware())
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(UserSessionAuthenticator())
    
//    let authenticated = app.routes.grouped([
//        app.sessions.middleware,
//        UserSessionAuthenticator(),
//    ])
//    
//    let portalRedirect = authenticated.grouped(AuthenticatedUser.redirectMiddleware(path: "login"))
    
    app.get("login") { req async throws in
        try await req.view.render("login", ["title": "Login"])
    }
    
    app.get("signup") { req async throws in
        try await req.view.render("signup", ["title": "Signup"])
    }
    
    app.get("portal") { req async throws in
        try await req.view.render("portal", ["title": "Portal"])
    }

    app.get("verify") { req async throws in
        return try await req.view.render("verify", ["title": "Verify"])
    }
    
    app.post("login", use: login)
    app.post("signup", use: signup)
    app.post("verify", use: verify)
}

@Sendable
func login(_ req: Request) async throws -> Response {
    let user = try req.content.decode(User.self)
    let response = try await req.application.cognito.authenticatable.authenticate(username: user.email,
                                                                                  password: user.password,
                                                                                  context: req)
    switch response {
    case .authenticated(let authenticatedResponse):
        req.auth.login(AuthenticatedUser(sessionID: authenticatedResponse.accessToken!))
    default:
        print("")
    }
    throw Abort.redirect(to: "portal")
}

@Sendable
func signup(_ req: Request) async throws -> Response {
    let user = try req.content.decode(User.self)
    let response = try await req.application.cognito.authenticatable.signUp(username: user.email, password: user.password, attributes: [:],
                                                                            on:req.eventLoop)
    throw Abort.redirect(to: "verify")
}

@Sendable
func verify(_ req: Request) async throws -> Response {
    let user = try req.content.decode(ConfirmUser.self)
    let response = try await req.application.cognito.authenticatable.confirmSignUp(username: user.email, confirmationCode: user.confirmation)
    throw Abort.redirect(to: "portal")
}

struct User: Content {
    var email: String
    var password: String
}

struct ConfirmUser: Content {
    var email: String
    var confirmation: String
}

struct AuthenticatedUser: SessionAuthenticatable {
    var sessionID: String
}

struct UserSessionAuthenticator: AsyncSessionAuthenticator {
    typealias User = AuthenticatedUser
    func authenticate(sessionID: String, for request: Vapor.Request) async throws {
        print("entered!")
        do {
            // TODO: handle response
            let response = try await request.application.cognito.authenticatable.authenticate(accessToken: sessionID, on: request.eventLoop)
            request.auth.login(User(sessionID: sessionID))
        } catch let error as SotoCognitoError { // invalid token
            return
        }
    }
}

struct LoggingMiddleware: AsyncMiddleware {
    func respond(to request: Vapor.Request, chainingTo next: any Vapor.AsyncResponder) async throws -> Vapor.Response {
        print("logged")
        return try await next.respond(to: request)
    }
    
    
}



