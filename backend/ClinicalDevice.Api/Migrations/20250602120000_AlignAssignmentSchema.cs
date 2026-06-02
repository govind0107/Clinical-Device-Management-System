using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ClinicalDevice.Api.Migrations;

public partial class AlignAssignmentSchema : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "IsSimulating",
            table: "Sessions");

        migrationBuilder.DropColumn(
            name: "SessionId",
            table: "Alerts");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "IsSimulating",
            table: "Sessions",
            type: "bit",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<Guid>(
            name: "SessionId",
            table: "Alerts",
            type: "uniqueidentifier",
            nullable: true);
    }
}
