package config

import (
	"github.com/caarlos0/env/v11"
)

type Config struct {
	UsePerfBuf          bool   `env:"DNSTRACER_USE_PERFBUF" envDefault:"false"`
	Interface           string `env:"DNSTRACER_INTERFACE" envDefault:"eth0"`
	Comprehensive       bool   `env:"DNSTRACER_COMPREHENSIVE" envDefault:"false"`
	MonitorAllBridges   bool   `env:"DNSTRACER_MONITOR_ALL_BRIDGES" envDefault:"false"`
	UseNamespaceTracing bool   `env:"DNSTRACER_USE_NAMESPACE_TRACING" envDefault:"false"`
}

func Load() (*Config, error) {
	cfg := &Config{}
	if err := env.Parse(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}
