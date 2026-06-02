using ClinicalDevice.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<Patient> Patients => Set<Patient>();
    public DbSet<Session> Sessions => Set<Session>();
    public DbSet<Reading> Readings => Set<Reading>();
    public DbSet<Alert> Alerts => Set<Alert>();
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Device>(e =>
        {
            e.HasKey(d => d.DeviceId);
            e.HasIndex(d => d.SerialNumber).IsUnique();
        });

        modelBuilder.Entity<Patient>(e =>
        {
            e.HasKey(p => p.PatientId);
            e.HasIndex(p => p.MRN).IsUnique();
        });

        modelBuilder.Entity<Session>(e =>
        {
            e.HasKey(s => s.SessionId);
            e.HasOne(s => s.Device).WithMany(d => d.Sessions).HasForeignKey(s => s.DeviceId);
            e.HasOne(s => s.Patient).WithMany(p => p.Sessions).HasForeignKey(s => s.PatientId).IsRequired(false);
        });

        modelBuilder.Entity<Reading>(e =>
        {
            e.HasKey(r => r.ReadingId);
            e.HasIndex(r => new { r.SessionId, r.Timestamp });
            e.HasOne(r => r.Session).WithMany(s => s.Readings).HasForeignKey(r => r.SessionId);
        });

        modelBuilder.Entity<Alert>(e =>
        {
            e.HasKey(a => a.AlertId);
            e.HasOne(a => a.Device).WithMany(d => d.Alerts).HasForeignKey(a => a.DeviceId);
        });

        modelBuilder.Entity<User>(e =>
        {
            e.HasKey(u => u.UserId);
            e.HasIndex(u => u.Username).IsUnique();
        });
    }
}
