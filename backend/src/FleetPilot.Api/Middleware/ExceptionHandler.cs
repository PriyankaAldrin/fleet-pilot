using FleetPilot.Api.Common;
using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace FleetPilot.Api.Middleware;

/// <summary>Maps exceptions to RFC 7807 problem details.</summary>
public static class Problems
{
    public static ProblemDetails From(Exception exception, HttpContext http, bool showDetail)
    {
        var (status, title) = exception switch
        {
            ValidationException => (StatusCodes.Status400BadRequest, "Validation failed"),
            BusinessRuleException => (StatusCodes.Status422UnprocessableEntity, "Request cannot be completed"),
            NotFoundException => (StatusCodes.Status404NotFound, "Not found"),
            ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
            ForbiddenException => (StatusCodes.Status403Forbidden, "Forbidden"),
            UnauthorizedException => (StatusCodes.Status401Unauthorized, "Unauthorized"),
            BadHttpRequestException b => (b.StatusCode, "Bad request"),
            _ => (StatusCodes.Status500InternalServerError, "Server error"),
        };

        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = status >= 500 && !showDetail ? "Something went wrong. Please try again." : exception.Message,
            Instance = http.Request.Path,
        };
        problem.Extensions["traceId"] = http.TraceIdentifier;
        if (exception is ValidationException ve)
        {
            problem.Detail = "One or more fields are invalid.";
            problem.Extensions["errors"] = ve.Errors
                .GroupBy(e => ToCamel(e.PropertyName))
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).Distinct().ToArray());
        }
        return problem;
    }

    private static string ToCamel(string s) => string.IsNullOrEmpty(s) ? s : char.ToLowerInvariant(s[0]) + s[1..];
}

/// <summary>Expected errors (validation, business rules, not found...) thrown by controllers and services.</summary>
public sealed class AppExceptionFilter(ILogger<AppExceptionFilter> logger) : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not (AppException or ValidationException)) return;
        var problem = Problems.From(context.Exception, context.HttpContext, showDetail: true);
        logger.LogInformation("{Status} {Title}: {Message}", problem.Status, problem.Title, context.Exception.Message);
        context.Result = new ObjectResult(problem) { StatusCode = problem.Status, ContentTypes = { "application/problem+json" } };
        context.ExceptionHandled = true;
    }
}

/// <summary>Everything else: logged as an error, details hidden outside Development.</summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger, IHostEnvironment env) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception exception, CancellationToken ct)
    {
        var problem = Problems.From(exception, http, env.IsDevelopment());
        if (problem.Status >= 500) logger.LogError(exception, "Unhandled exception");
        http.Response.StatusCode = problem.Status ?? 500;
        await http.Response.WriteAsJsonAsync(problem, (System.Text.Json.JsonSerializerOptions?)null, "application/problem+json", ct);
        return true;
    }
}
