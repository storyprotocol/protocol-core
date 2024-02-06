# CHANGELOG

## Beta-rc3

This release finalizes the external-facing implementation of core modules and registries, as well as the public interfaces and events.

- Split old LicensingRegistry into LicenseRegistry and LicensingModule, where the former stores and deals with all 1155-related data & actions, and the latter stores and facilitates all policy-related data & actions (#72)
- Introduce the IPAssetRegistry that replaces IPRecordRegistry and inherits IPAccountRegistry (#46)
- Add logic and helper contracts to the royalty system using 0xSplits to facilitate enforceable on-chain royalty payment (#53)
- Integrate the core royalty and licensing logic to enforce the terms of commercial license policies with royalty requirements on derivatives (#60, #65, #67)
- Accommodate a modifier-based approach for Access Control; Provide optionality for access control checks; and Improve other AccessController states and functionalities (#45, #63, #70)
- Enable mutable royalty policy settings to provide greater flexibility for IPAccount owners (#67, #73)
- Finalize the canonical metadata provider with flexible provisioning (#49)
- Simplify the concept of frameworks and license policies into PolicyFrameworkManager, which manages all policy registration and executes custom, per-framework actions (#51); Licensing refactored from parameter-based to framework-based flows (#44)
- Enable multi-parent linking for derivatives (#56) and add policy compatibility checks for multi-parent and multi-derivative linking (#61, #66)
- Enhance the UMLPolicyFrameworkManager and UMLPolicy with new structs and fields to execute compatibility checks easily and more efficiently (#65)
- Establish a new integration test framework and test flows and improve existing unit test frameworks (#52, #57, #58)
- Create a basic, functioning Disputer Module with arbitration settings (#62)
- Review interfaces, events, and variables (#76) and GitHub PR actions (#36, #58)
- Refactor contracts for relative imports (#75)

## Beta-rc2

This release introduces new modules, registries, libraries, and other logics into the protocol.

- Define concrete Events and Interfaces for all modules and registries (#25, #28, #29)
- Introduce a simple governance mechanism (#35)
- Add a canonical IPMetadataProvider as the default resolver and add more resolvers (#30)
- Add a basic IPAssetRenderer for rendering canonical metadata associated with each IP Asset (#30)
- Accommodate more flexible Records for resolvers in the IP Record Registry (#30)
- Support meta-transaction (execution with signature) on IPAccount implementation (#32)
- Upgrade License Registry logics for more expressive and comprehensive parameter verifiers (hooks) and license policy enforcement for derivative IPAssets (#23, #31)
- Enhance the deployment script & post-deployment interactions, as well as the Integration tests to capture more use-case flows (#33)
- Enhance the Unit tests for better coverage (#29, #30, #35)

## Beta-rc1
