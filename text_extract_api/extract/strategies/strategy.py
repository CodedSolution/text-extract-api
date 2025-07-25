from __future__ import annotations
import os
import yaml
import importlib
import pkgutil
from typing import Type, Dict

from extract.extract_result import ExtractResult
from text_extract_api.files.file_formats.file_format import FileFormat


class Strategy:
    # ✅ Add missing class-level attributes
    _strategies: Dict[str, Strategy] = {}
    _strategy_config_map: Dict[str, dict] = {}

    def __init__(self, strategy_config=None, update_state_callback=None):
        self._strategy_config = strategy_config or {}
        self.update_state_callback = update_state_callback or (lambda **kwargs: None)

    def set_strategy_config(self, config: Dict):
        self._strategy_config = config

    def set_update_state_callback(self, callback):
        self.update_state_callback = callback

    def update_state(self, state, meta):
        if self.update_state_callback:
            self.update_state_callback(state, meta)

    @classmethod
    def name(cls) -> str:
        raise NotImplementedError("Strategy subclasses must implement name()")

    def extract_text(self, file_format: FileFormat, language: str = 'en') -> ExtractResult:
        raise NotImplementedError("Strategy subclasses must implement extract_text()")

    @classmethod
    def get_strategy(cls, name: str) -> Strategy:
        """
        Returns the registered strategy instance by name.
        Auto-loads from config or autodiscovers if not yet registered.
        """
        if name not in cls._strategies:
            cls.load_strategies_from_config()

        if name not in cls._strategies:
            cls.autodiscover_strategies()

        if name not in cls._strategies:
            available = ', '.join(cls._strategies.keys())
            raise ValueError(f"Unknown strategy '{name}'. Available: {available}")

        return cls._strategies[name]

    @classmethod
    def register_strategy(cls, strategy_instance: Strategy, name: str = None, override: bool = False):
        """
        Registers a strategy instance.
        """
        name = name or strategy_instance.name()
        if override or name not in cls._strategies:
            cls._strategies[name] = strategy_instance

    @classmethod
    def load_strategies_from_config(cls, path: str = os.getenv('OCR_CONFIG_PATH', 'config/strategies.yaml')):
        """
        Loads strategies from a YAML configuration file.
        """
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(path)))
        config_file_path = os.path.join(project_root, path)

        if not os.path.isfile(config_file_path):
            raise FileNotFoundError(f"Config file not found at path: {config_file_path}")

        with open(config_file_path, 'r') as f:
            config = yaml.safe_load(f)

        if 'strategies' not in config or not isinstance(config['strategies'], dict):
            raise ValueError(f"Missing or invalid 'strategies' section in the {config_file_path} file")

        for strategy_name, strategy_config in config['strategies'].items():
            if 'class' not in strategy_config:
                raise ValueError(f"Missing 'class' attribute for OCR strategy: {strategy_name}")

            strategy_class_path = strategy_config['class']
            module_path, class_name = strategy_class_path.rsplit('.', 1)
            module = importlib.import_module(module_path)

            strategy_cls = getattr(module, class_name)
            strategy_instance = strategy_cls()
            strategy_instance.set_strategy_config(strategy_config)

            cls.register_strategy(strategy_instance, strategy_name)
            cls._strategy_config_map[strategy_name] = strategy_config
            print(f"✅ Loaded strategy: {strategy_name} ({strategy_class_path})")

    @classmethod
    def autodiscover_strategies(cls) -> Dict[str, Strategy]:
        """
        Auto-discovers and registers any strategy classes under text_extract_api.*.strategies.*
        """
        for module_info in pkgutil.iter_modules():
            if not module_info.name.startswith("text_extract_api"):
                continue

            try:
                module = importlib.import_module(module_info.name)
            except ImportError:
                continue

            if not hasattr(module, "__path__"):
                continue

            for submodule_info in pkgutil.walk_packages(module.__path__, module_info.name + "."):
                if ".strategies." not in submodule_info.name:
                    continue

                try:
                    strategy_module = importlib.import_module(submodule_info.name)
                except ImportError as e:
                    print(f"❌ Error importing strategy module '{submodule_info.name}': {e}")
                    continue

                for attr_name in dir(strategy_module):
                    attr = getattr(strategy_module, attr_name)
                    if (
                        isinstance(attr, type)
                        and issubclass(attr, Strategy)
                        and attr is not Strategy
                    ):
                        strategy_name = attr.name()
                        if strategy_name not in cls._strategies:
                            instance = attr()
                            cls.register_strategy(instance, strategy_name)
                            print(f"🔍 Auto-discovered strategy: {strategy_name} from {submodule_info.name}")
