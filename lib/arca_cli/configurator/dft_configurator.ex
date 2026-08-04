defmodule Arca.Cli.Configurator.DftConfigurator do
  @moduledoc """
  `Arca.Cli.Configurator.DftConfigurator` is a default implementation of the ConfiguratorBehaviour (using BaseConfigurator) that configures the CLI to use the basic predefined commands.
  """
  use Arca.Cli.Configurator.BaseConfigurator

  config :arca_cli,
    commands: [
      Arca.Cli.Commands.AboutCommand,
      Arca.Cli.Commands.CliHistoryCommand,
      Arca.Cli.Commands.CliDebugCommand,
      Arca.Cli.Commands.CliErrorCommand,
      Arca.Cli.Commands.CliRedoCommand,
      Arca.Cli.Commands.CliScriptCommand,
      Arca.Cli.Commands.CliStatusCommand,
      Arca.Cli.Commands.DevInfoCommand,
      Arca.Cli.Commands.DevDepsCommand,
      Arca.Cli.Commands.CfgListCommand,
      Arca.Cli.Commands.CfgGetCommand,
      Arca.Cli.Commands.CfgHelpCommand,
      Arca.Cli.Commands.ReplCommand,
      Arca.Cli.Commands.SettingsAllCommand,
      Arca.Cli.Commands.SettingsGetCommand,
      Arca.Cli.Commands.SysCmdCommand,
      Arca.Cli.Commands.SysFlushCommand,
      Arca.Cli.Commands.SysInfoCommand,
      Arca.Cli.Commands.DbgEchoCommand,
      Arca.Cli.Commands.DbgTokensCommand
    ],
    # Branding comes from the app's own config, not from placeholders baked in
    # here. `:version` is deliberately not declared: BaseConfigurator resolves it
    # from the application spec, which is generated from the VERSION file.
    author: Application.compile_env(:arca_cli, :author, ""),
    about: Application.compile_env(:arca_cli, :about, ""),
    description: Application.compile_env(:arca_cli, :description, "")
end
