namespace FleetPilot.Api.Common;

public abstract class AppException(string message) : Exception(message);

public sealed class NotFoundException(string message) : AppException(message)
{
    public static NotFoundException For(string entity, object id) => new($"{entity} {id} was not found.");
}

public sealed class ConflictException(string message) : AppException(message);

public sealed class BusinessRuleException(string message) : AppException(message);

public sealed class ForbiddenException(string message) : AppException(message);

public sealed class UnauthorizedException(string message) : AppException(message);
