import Vapor
import NIO
import SotoCognitoAuthentication
import SotoCognitoAuthenticationKit
import SotoCognitoIdentityProvider
import SotoCognitoIdentity
import Fluent


func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("home", ["title": "Home"])
    }
    
    let authenticated = app.routes.grouped([
        app.sessions.middleware,
        UserSessionAuthenticator(),
    ])
    
    let portalRedirect = authenticated.grouped(AuthenticatedUser.redirectMiddleware(path: "login"))
    
    app.get("login") { req async throws in
        try await req.view.render("login", ["title": "Login"])
    }
    
    app.get("signup") { req async throws in
        try await req.view.render("signup", ["title": "Signup"])
    }
    
    portalRedirect.get("portal") { req async throws in
        try await req.view.render("portal", ["title": "Portal"])
    }

    app.get("verify") { req async throws in
        return try await req.view.render("verify", ["title": "Verify"])
    }
    
    authenticated.post("login", use: login)
    authenticated.post("signup", use: signup)
    authenticated.post("verify", use: verify)
}

@Sendable
func login(_ req: Request) async throws -> Response {
    do {
        let user = try req.content.decode(LoginUser.self)
        let response = try await req.application.cognito.authenticatable.authenticate(username: user.email,
                                                                                      password: user.password,
                                                                                      context: req)
        switch response {
        case .authenticated(let authenticatedResponse):
            let user = AuthenticatedUser(sessionID: authenticatedResponse.accessToken!)
            req.auth.login(user)
            req.session.authenticate(user)
        case .challenged(let challengedResponse): // TODO: handle challenged
            break
        }
        return req.redirect(to: "portal")
    } catch let error as SotoCognitoError {
        // TODO: handle cases (unauthorized, unexpectedResult, invalidPublicKey)
        return try await req.view.render("login", ["title": "Login"]).encodeResponse(status: .unauthorized, for: req)
    } catch {
        return try await req.view.render("login", ["title": "Login"]).encodeResponse(status: .unauthorized, for: req)
    }
}

@Sendable
func signup(_ req: Request) async throws -> Response {
    // TODO: wrap in do catch and handle errors
    let user = try req.content.decode(LoginUser.self)
    let _ = try await req.application.cognito.authenticatable.signUp(username: user.email, password: user.password, attributes: [:],
                                                                            on:req.eventLoop)
    return req.redirect(to: "verify")
}

@Sendable
func verify(_ req: Request) async throws -> Response {
    // TODO: wrap in do catch and handle errors
    let user = try req.content.decode(ConfirmUser.self)
    try await req.application.cognito.authenticatable.confirmSignUp(username: user.email, confirmationCode: user.confirmation)
    return req.redirect(to: "login")
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
        do {
            // TODO: handle response
            let response = try await request.application.cognito.authenticatable.authenticate(accessToken: sessionID, on: request.eventLoop)
            request.auth.login(User(sessionID: sessionID))
        } catch let error as SotoCognitoError { // TODO: handle invalid token / other errors
            return
        }
    }
}

struct LoginUser: Content {
    var email: String
    var password: String
}



