using ClinicalDevice.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext db)
    {
        await EnsureDatabaseAsync(db);

        if (await db.Users.AnyAsync()) return;

        db.Users.AddRange(
            new User
            {
                UserId = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                Username = "admin",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin123!"),
                Role = "Admin"
            },
            new User
            {
                UserId = Guid.Parse("22222222-2222-2222-2222-222222222222"),
                Username = "clinician",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Clinician123!"),
                Role = "Clinician"
            },
            new User
            {
                UserId = Guid.Parse("33333333-3333-3333-3333-333333333333"),
                Username = "tech",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Tech123!"),
                Role = "Tech"
            });

        var device1 = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        var device2 = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
        var device3 = Guid.Parse("cccccccc-cccc-cccc-cccc-cccccccccccc");

        db.Devices.AddRange(
            new Device
            {
                DeviceId = device1,
                SerialNumber = "MON-ECG-001",
                Model = "VitalTrack Pro",
                Status = "Online",
                LastSeen = DateTime.UtcNow,
                CalibrationDate = DateTime.UtcNow.AddMonths(-2)
            },
            new Device
            {
                DeviceId = device2,
                SerialNumber = "MON-SPO2-002",
                Model = "OxySense X2",
                Status = "Offline",
                LastSeen = DateTime.UtcNow.AddHours(-3),
                CalibrationDate = DateTime.UtcNow.AddMonths(-1)
            },
            new Device
            {
                DeviceId = device3,
                SerialNumber = "MON-BP-003",
                Model = "PressureLink 5",
                Status = "Online",
                LastSeen = DateTime.UtcNow.AddMinutes(-5),
                CalibrationDate = DateTime.UtcNow.AddDays(-10)
            });

        db.Patients.AddRange(
            new Patient
            {
                PatientId = Guid.Parse("dddddddd-dddd-dddd-dddd-dddddddddddd"),
                Name = "Alex Morgan (Synthetic)",
                DateOfBirth = new DateTime(1985, 4, 12),
                MRN = "SYN-10001"
            },
            new Patient
            {
                PatientId = Guid.Parse("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"),
                Name = "Jordan Lee (Synthetic)",
                DateOfBirth = new DateTime(1992, 9, 3),
                MRN = "SYN-10002"
            });

        await db.SaveChangesAsync();
    }

    /// <summary>
    /// Applies EF migrations. Rebuilds legacy SQLite DBs created with EnsureCreated (old schema).
    /// </summary>
    private static async Task EnsureDatabaseAsync(AppDbContext db)
    {
        if (db.Database.IsSqlite())
        {
            if (await NeedsSqliteRebuildAsync(db))
            {
                await db.Database.EnsureDeletedAsync();
            }
            await db.Database.EnsureCreatedAsync();
        }
        else
        {
            await db.Database.MigrateAsync();
        }
    }

    private static async Task<bool> NeedsSqliteRebuildAsync(AppDbContext db)
    {
        try
        {
            if (!await db.Database.CanConnectAsync()) return false;

            var applied = (await db.Database.GetAppliedMigrationsAsync()).ToList();
            if (applied.Contains("20250602120000_AlignAssignmentSchema")) return false;

            // Legacy column removed from the model but may still exist in old SQLite files.
            var connection = db.Database.GetDbConnection();
            await connection.OpenAsync();
            try
            {
                await using var cmd = connection.CreateCommand();
                cmd.CommandText = "SELECT 1 FROM pragma_table_info('Sessions') WHERE name = 'IsSimulating' LIMIT 1";
                var result = await cmd.ExecuteScalarAsync();
                return result is not null;
            }
            finally
            {
                await connection.CloseAsync();
            }
        }
        catch
        {
            return false;
        }
    }
}
