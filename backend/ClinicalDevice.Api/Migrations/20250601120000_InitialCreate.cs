using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ClinicalDevice.Api.Migrations;

public partial class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Devices",
            columns: table => new
            {
                DeviceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                SerialNumber = table.Column<string>(type: "nvarchar(450)", nullable: false),
                Model = table.Column<string>(type: "nvarchar(max)", nullable: false),
                Status = table.Column<string>(type: "nvarchar(max)", nullable: false),
                LastSeen = table.Column<DateTime>(type: "datetime2", nullable: true),
                CalibrationDate = table.Column<DateTime>(type: "datetime2", nullable: true)
            },
            constraints: table => table.PrimaryKey("PK_Devices", x => x.DeviceId));

        migrationBuilder.CreateTable(
            name: "Patients",
            columns: table => new
            {
                PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Name = table.Column<string>(type: "nvarchar(max)", nullable: false),
                DateOfBirth = table.Column<DateTime>(type: "datetime2", nullable: false),
                MRN = table.Column<string>(type: "nvarchar(450)", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_Patients", x => x.PatientId));

        migrationBuilder.CreateTable(
            name: "Users",
            columns: table => new
            {
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Username = table.Column<string>(type: "nvarchar(450)", nullable: false),
                PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: false),
                Role = table.Column<string>(type: "nvarchar(max)", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_Users", x => x.UserId));

        migrationBuilder.CreateTable(
            name: "Alerts",
            columns: table => new
            {
                AlertId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                DeviceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                Severity = table.Column<string>(type: "nvarchar(max)", nullable: false),
                Message = table.Column<string>(type: "nvarchar(max)", nullable: false),
                CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                Acknowledged = table.Column<bool>(type: "bit", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Alerts", x => x.AlertId);
                table.ForeignKey(
                    name: "FK_Alerts_Devices_DeviceId",
                    column: x => x.DeviceId,
                    principalTable: "Devices",
                    principalColumn: "DeviceId",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateTable(
            name: "Sessions",
            columns: table => new
            {
                SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                DeviceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                PatientId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                StartTime = table.Column<DateTime>(type: "datetime2", nullable: false),
                EndTime = table.Column<DateTime>(type: "datetime2", nullable: true),
                IsSimulating = table.Column<bool>(type: "bit", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Sessions", x => x.SessionId);
                table.ForeignKey(
                    name: "FK_Sessions_Devices_DeviceId",
                    column: x => x.DeviceId,
                    principalTable: "Devices",
                    principalColumn: "DeviceId",
                    onDelete: ReferentialAction.Cascade);
                table.ForeignKey(
                    name: "FK_Sessions_Patients_PatientId",
                    column: x => x.PatientId,
                    principalTable: "Patients",
                    principalColumn: "PatientId");
            });

        migrationBuilder.CreateTable(
            name: "Readings",
            columns: table => new
            {
                ReadingId = table.Column<long>(type: "bigint", nullable: false)
                    .Annotation("SqlServer:Identity", "1, 1"),
                SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Timestamp = table.Column<DateTime>(type: "datetime2", nullable: false),
                Channel = table.Column<string>(type: "nvarchar(max)", nullable: false),
                Value = table.Column<double>(type: "float", nullable: false),
                Unit = table.Column<string>(type: "nvarchar(max)", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_Readings", x => x.ReadingId);
                table.ForeignKey(
                    name: "FK_Readings_Sessions_SessionId",
                    column: x => x.SessionId,
                    principalTable: "Sessions",
                    principalColumn: "SessionId",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(name: "IX_Alerts_DeviceId", table: "Alerts", column: "DeviceId");
        migrationBuilder.CreateIndex(name: "IX_Devices_SerialNumber", table: "Devices", column: "SerialNumber", unique: true);
        migrationBuilder.CreateIndex(name: "IX_Patients_MRN", table: "Patients", column: "MRN", unique: true);
        migrationBuilder.CreateIndex(name: "IX_Readings_SessionId_Timestamp", table: "Readings", columns: new[] { "SessionId", "Timestamp" });
        migrationBuilder.CreateIndex(name: "IX_Sessions_DeviceId", table: "Sessions", column: "DeviceId");
        migrationBuilder.CreateIndex(name: "IX_Sessions_PatientId", table: "Sessions", column: "PatientId");
        migrationBuilder.CreateIndex(name: "IX_Users_Username", table: "Users", column: "Username", unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Alerts");
        migrationBuilder.DropTable(name: "Readings");
        migrationBuilder.DropTable(name: "Sessions");
        migrationBuilder.DropTable(name: "Users");
        migrationBuilder.DropTable(name: "Patients");
        migrationBuilder.DropTable(name: "Devices");
    }
}
