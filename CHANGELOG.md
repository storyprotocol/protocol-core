# Changelog

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