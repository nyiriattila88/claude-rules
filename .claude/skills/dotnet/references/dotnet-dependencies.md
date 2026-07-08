---
description: This file provides guidelines for safely managing NuGet package dependencies in .NET projects, focusing on security, licensing, and maintainability.
globs: Directory.Packages.props,*.csproj,*.fsproj,Directory.Build.props,nuget.config
alwaysApply: false
---

# Claude Rules File: Best Practices for .NET Dependency Management
Role Definition:
 - Package Management Expert
 - Security Analyst
 - License Compliance Specialist

General:
  Description: >
    .NET projects must manage their dependencies using secure and consistent practices,
    with attention to security vulnerabilities, license compliance, and proper version
    management through the dotnet CLI.
  Requirements:
    - Use dotnet CLI for package management
    - Verify package licenses before installation
    - Monitor for security vulnerabilities
    - Maintain consistent versioning strategies
    - Use lock files and enforce locked restore mode in CI/CD

Package Lock Files:
  - Enable lock file generation centrally:
      - Set `RestorePackagesWithLockFile` in `Directory.Build.props`:
      ```xml
      <Project>
        <PropertyGroup>
          <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
        </PropertyGroup>
      </Project>
      ```
  - Keep `packages.lock.json` under source control
  - Ensure lock file is not copied to output/publish artifacts:
      - Example in `Directory.Build.targets`:
      ```xml
      <Project>
        <ItemGroup Condition="Exists('packages.lock.json')">
          <Content Remove="packages.lock.json" />
          <None Remove="packages.lock.json" />
          <None Include="packages.lock.json">
            <CopyToPublishDirectory>Never</CopyToPublishDirectory>
            <CopyToOutputDirectory>Never</CopyToOutputDirectory>
          </None>
        </ItemGroup>
      </Project>
      ```
  - CI/CD restore must run in a dedicated locked-mode step (use **`-c Release`** on restore so warning-as-error policy matches build; see `dotnet-locked-restore-ci.md`):
      - `dotnet restore --locked-mode -c Release`
      - `dotnet build -c Release --no-restore`
      - `dotnet test -c Release --no-build`

  ✅ DO:
  - Commit `packages.lock.json` changes when dependencies change
  - Fail CI if lock file and dependency graph are out of sync
  - Keep restore separate from build/test in pipeline steps

  ❌ DON'T:
  - Run `dotnet build` as the first dependency-resolution command in CI
  - Mix restore into build/test steps
  - Exclude lock files from source control when using locked-mode restore

Package Installation:
  - Always use dotnet CLI commands:
      - Preferred: `dotnet add package <PackageId> [-v <Version>]`
      - Avoid manual .csproj/.fsproj edits
      - Examples:
        ```bash
        # Add latest stable version
        dotnet add package Newtonsoft.Json
        
        # Add specific version
        dotnet add package Serilog -v 3.1.1
        
        # Add package to specific project
        dotnet add MyProject/MyProject.csproj package Microsoft.Extensions.Logging
        ```
  - Before installation:
      - Check package license compatibility
      - Review package download statistics
      - Verify package authenticity (signed packages)
      - Consider package maintenance status

Check and Upgrade NuGet Packages:

  To check for outdated packages and upgrade them in your .NET solution:

  1. **Check for outdated packages**
     ```bash
     dotnet list package --outdated
     ```
     This command will show:
     - Currently used version ("Resolved")
     - Latest available version ("Latest")
     - The version you're requesting ("Requested")

  2. **Update package versions**
     - If using central package management (Directory.Packages.props):
       - Update the versions in `Directory.Packages.props`:
       ```xml
       <PackageVersion Include="PackageName" Version="NewVersion" />
       ```

     - If using traditional package references:
       ```bash
       dotnet add package PackageName --version NewVersion
       ```

  3. **Restore and verify**
     ```bash
     dotnet restore
     dotnet build
     dotnet test
     ```

  Example output of `dotnet list package --outdated`:
  ```
  Project `MyProject` has the following updates to its packages
     [netstandard2.1]:
     Top-level Package      Requested   Resolved   Latest
     > Akka.Streams         1.5.13      1.4.45     1.5.38
  ```

  Note: After updating packages, always:
  1. Check for breaking changes in the package's release notes
  2. Build the solution to catch any compatibility issues
  3. Run tests to ensure everything still works
  4. Review and update any code that needs to be modified for the new versions

Security Considerations:
  - Enable security scanning:
      - Run `dotnet restore --use-lock-file` to generate/update lock file locally
      - Run `dotnet restore --locked-mode` in CI/CD for reproducible restores
      - Use `dotnet list package --vulnerable` to check for known vulnerabilities
      - Configure GitHub Dependabot or similar tools
  - Monitor security:
      - Subscribe to security advisories
      - Regular vulnerability scanning in CI/CD
      - Automated security updates for patch versions
  - Example workflow:
    ```bash
    # Generate lock file
    dotnet restore --use-lock-file
    
    # Check for vulnerabilities
    dotnet list package --vulnerable
    
    # Update vulnerable package
    dotnet add package VulnerablePackage -v SecureVersion
    
    # Regenerate lock file
    dotnet restore --force-evaluate
    ```

License Compliance:
  - Verify licenses before adding dependencies:
      - Check license compatibility with your project
      - Document license requirements
      - Maintain license inventory
  - Common OSS-friendly licenses:
      - MIT
      - Apache 2.0
      - BSD
      - MS-PL
  - Warning signs:
      - No license specified
      - Restrictive licenses (GPL for commercial software)
      - License changes between versions

Version Management:
  - Use semantic versioning:
      - Lock major versions for stability
      - Allow minor updates for features
      - Auto-update patches for security
  - Version constraints:
      - Avoid floating versions (*)
      - Use minimum version constraints when needed
      - Document version decisions
  - Example in Directory.Packages.props:
    ```xml
    <Project>
      <ItemGroup>
        <!-- Locked major version -->
        <PackageVersion Include="Important.Package" Version="2.0.0" />
        
        <!-- Allow minor updates -->
        <PackageVersion Include="Feature.Package" Version="[3.0,4.0)" />
        
        <!-- Allow patch updates -->
        <PackageVersion Include="Stable.Package" Version="[1.2.3,1.3.0)" />
      </ItemGroup>
    </Project>
    ```

Maintenance:
  - Regular housekeeping:
      - Remove unused packages
      - Consolidate duplicate dependencies
      - Update documentation
  - Automation:
      - Implement automated vulnerability scanning
      - Set up dependency update workflows
      - Configure license compliance checks
  - Commands for maintenance:
    ```bash
    # List all packages
    dotnet list package
    
    # Check for unused dependencies
    dotnet remove package UnusedPackage
    
    # Clean solution
    dotnet clean
    dotnet restore --force
    ```

Integration with CI/CD:
  - Implement checks:
      - Vulnerability scanning
      - License compliance
      - Package restore verification using locked mode
  - Example GitHub Actions workflow:
    ```yaml
    - name: Restore (locked mode, Release)
      run: dotnet restore --locked-mode -c Release

    - name: Security scan
      run: |
        dotnet list package --vulnerable

    - name: Build
      run: dotnet build -c Release --no-restore

    - name: Test
      run: dotnet test -c Release --no-build
        
    - name: License check
      run: dotnet-project-licenses
    ```

# End of Claude Rules File 