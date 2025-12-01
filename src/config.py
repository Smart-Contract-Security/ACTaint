# DATASET_PATH = "datasets/clean_datasets/ACFix/"
# DATASET_PATH = "datasets/clean_datasets/624sol/"
DATASET_PATH = "datasets/clean_datasets/CVE/"

# ablation study
No_static = False
No_taint = False

# external library
# slither_library = []
# slither_library = ["solmate/=datasets/clean_datasets/ACFix/selfbuild/BondFixedExpiryTeller/lib/solmate/src/", "clones/=datasets/clean_datasets/ACFix/selfbuild/BondFixedExpiryTeller/lib/clones-with-immutable-args/src/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/selfbuild/StaxLPStaking/@openzeppelin/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/selfbuild/GymSinglePool/@openzeppelin/", "@quant-finance/=datasets/clean_datasets/ACFix/selfbuild/GymSinglePool/@quant-finance/"]
# slither_library = ["@openzeppelin/=datasets/@openzeppelin/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/selfbuild/MintableAutoCompundRelockBonus/@openzeppelin/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/self-build/QBridge/@openzeppelin/"]
# slither_library = ["solmate/=datasets/clean_datasets/ACFix/self-build/BondFixedExpiryTeller/lib/solmate/src/"]
# slither_library = ["@openzeppelin/=datasets/@openzeppelin/","@ensdomains=./datasets/@ensdomains"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/StaxLPStaking/@openzeppelin/"]
# slither_library = ["solmate/=datasets/clean_datasets/ACFix/self-build/BondFixedExpiryTeller/lib/solmate/src/","clones/=datasets/clean_datasets/ACFix/self-build/BondFixedExpiryTeller/lib/clones-with-immutable-args/src/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/self-build/TreasureMarketplaceBuyer/@openzeppelin/"]
# slither_library = ["@openzeppelin/=datasets/clean_datasets/ACFix/self-build/Replica/node_modules/@openzeppelin/","@summa-tx=datasets/clean_datasets/ACFix/self-build/Replica/node_modules/@summa-tx/"]

gpt_url = ""  # gpt url
gpt_key = "" # GPT key
gpt_model = "gpt-4o"
# gpt_model = "gpt-4o-mini"
# gpt_model = "deepseek-r1"
gpt_temperature = 0
gpt_top_p = 0.9
gpt_max_tokens = 2048

total_token = 0

slither_library = []
SOL_FILE = 'CVE-2018-10666.sol'
SOL_FILE_PATH = DATASET_PATH + SOL_FILE
