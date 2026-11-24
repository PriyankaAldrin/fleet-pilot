using FleetPilot.Api.Dtos;
using FluentValidation;

namespace FleetPilot.Api.Validators;

internal static class Rules
{
    public const int MaxOdometer = 9_999_999;

    public static IRuleBuilderOptions<T, string> Password<T>(this IRuleBuilder<T, string> rule) =>
        rule.NotEmpty().MinimumLength(8).MaximumLength(100)
            .Matches("[A-Za-z]").WithMessage("Password must contain a letter.")
            .Matches("[0-9]").WithMessage("Password must contain a number.");

    public static IRuleBuilderOptions<T, string?> Phone<T>(this IRuleBuilder<T, string?> rule) =>
        rule.MaximumLength(30).Matches(@"^[+0-9 ()\-]*$").WithMessage("Phone may only contain digits, spaces, +, - and brackets.");
}

public sealed class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).NotEmpty();
    }
}

public sealed class RefreshRequestValidator : AbstractValidator<RefreshRequest>
{
    public RefreshRequestValidator() => RuleFor(x => x.RefreshToken).NotEmpty();
}

public sealed class ChangePasswordRequestValidator : AbstractValidator<ChangePasswordRequest>
{
    public ChangePasswordRequestValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty();
        RuleFor(x => x.NewPassword).Password().NotEqual(x => x.CurrentPassword).WithMessage("New password must be different.");
    }
}

public sealed class CreateAdminRequestValidator : AbstractValidator<CreateAdminRequest>
{
    public CreateAdminRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Phone).Phone();
        RuleFor(x => x.Password).Password();
    }
}

public sealed class UpdateAdminRequestValidator : AbstractValidator<UpdateAdminRequest>
{
    public UpdateAdminRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Phone).Phone();
        RuleFor(x => x.NewPassword!).Password().When(x => !string.IsNullOrEmpty(x.NewPassword));
    }
}

public sealed class CreateDriverRequestValidator : AbstractValidator<CreateDriverRequest>
{
    public CreateDriverRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Phone).Phone();
        RuleFor(x => x.Password).Password();
        RuleFor(x => x.LicenseNo).NotEmpty().MaximumLength(50);
    }
}

public sealed class UpdateDriverRequestValidator : AbstractValidator<UpdateDriverRequest>
{
    public UpdateDriverRequestValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(150);
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Phone).Phone();
        RuleFor(x => x.LicenseNo).NotEmpty().MaximumLength(50);
        RuleFor(x => x.NewPassword!).Password().When(x => !string.IsNullOrEmpty(x.NewPassword));
    }
}

public abstract class VehicleValidatorBase<T> : AbstractValidator<T>
{
    protected void Common(
        System.Linq.Expressions.Expression<Func<T, string>> plate,
        System.Linq.Expressions.Expression<Func<T, string>> make,
        System.Linq.Expressions.Expression<Func<T, string>> model,
        System.Linq.Expressions.Expression<Func<T, int>> year,
        System.Linq.Expressions.Expression<Func<T, string?>> color,
        System.Linq.Expressions.Expression<Func<T, int>> odometer)
    {
        RuleFor(plate).NotEmpty().MaximumLength(20);
        RuleFor(make).NotEmpty().MaximumLength(50);
        RuleFor(model).NotEmpty().MaximumLength(50);
        RuleFor(year).InclusiveBetween(1980, DateTime.UtcNow.Year + 1);
        RuleFor(color).MaximumLength(30);
        RuleFor(odometer).InclusiveBetween(0, Rules.MaxOdometer);
    }
}

public sealed class CreateVehicleRequestValidator : VehicleValidatorBase<CreateVehicleRequest>
{
    public CreateVehicleRequestValidator() =>
        Common(x => x.PlateNo, x => x.Make, x => x.Model, x => x.Year, x => x.Color, x => x.CurrentOdometer);
}

public sealed class UpdateVehicleRequestValidator : VehicleValidatorBase<UpdateVehicleRequest>
{
    public UpdateVehicleRequestValidator() =>
        Common(x => x.PlateNo, x => x.Make, x => x.Model, x => x.Year, x => x.Color, x => x.CurrentOdometer);
}

public sealed class StartShiftFormValidator : AbstractValidator<StartShiftForm>
{
    public StartShiftFormValidator()
    {
        RuleFor(x => x.ClientId).NotEmpty();
        RuleFor(x => x.VehicleId).GreaterThan(0);
        RuleFor(x => x.StartKm).InclusiveBetween(0, Rules.MaxOdometer);
        RuleFor(x => x.OcrKm).InclusiveBetween(0, Rules.MaxOdometer).When(x => x.OcrKm.HasValue);
        RuleFor(x => x.OcrConfidence).InclusiveBetween(0, 1).When(x => x.OcrConfidence.HasValue);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90).When(x => x.Latitude.HasValue);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180).When(x => x.Longitude.HasValue);
        RuleFor(x => x.Notes).MaximumLength(500);
        RuleFor(x => x.Photo).NotNull().WithMessage("An odometer photo is required.");
    }
}

public sealed class EndShiftFormValidator : AbstractValidator<EndShiftForm>
{
    public EndShiftFormValidator()
    {
        RuleFor(x => x.EndKm).InclusiveBetween(0, Rules.MaxOdometer);
        RuleFor(x => x.OcrKm).InclusiveBetween(0, Rules.MaxOdometer).When(x => x.OcrKm.HasValue);
        RuleFor(x => x.OcrConfidence).InclusiveBetween(0, 1).When(x => x.OcrConfidence.HasValue);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90).When(x => x.Latitude.HasValue);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180).When(x => x.Longitude.HasValue);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed class ReviewShiftRequestValidator : AbstractValidator<ReviewShiftRequest>
{
    public ReviewShiftRequestValidator()
    {
        RuleFor(x => x.StartKm).InclusiveBetween(0, Rules.MaxOdometer).When(x => x.StartKm.HasValue);
        RuleFor(x => x.EndKm).InclusiveBetween(0, Rules.MaxOdometer).When(x => x.EndKm.HasValue);
        RuleFor(x => x.ReviewNotes).MaximumLength(1000);
    }
}

public sealed class ReportQueryValidator : AbstractValidator<ReportQuery>
{
    public ReportQueryValidator()
    {
        RuleFor(x => x.To).GreaterThanOrEqualTo(x => x.From).WithMessage("'To' must be on or after 'From'.");
    }
}
