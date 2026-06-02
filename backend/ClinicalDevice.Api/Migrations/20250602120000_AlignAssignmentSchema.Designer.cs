using ClinicalDevice.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ClinicalDevice.Api.Migrations;

[DbContext(typeof(AppDbContext))]
[Migration("20250602120000_AlignAssignmentSchema")]
partial class AlignAssignmentSchema
{
    protected override void BuildTargetModel(ModelBuilder modelBuilder)
    {
        modelBuilder.HasAnnotation("ProductVersion", "10.0.0");
    }
}
