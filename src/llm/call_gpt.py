import config

from openai import OpenAI

def call_chatgpt(messages) -> list:

    client = OpenAI(
        base_url=config.gpt_url,
        api_key=config.gpt_key,
    )

    res = client.chat.completions.create(model=config.gpt_model, messages=messages,
                                         temperature=config.gpt_temperature,
                                         top_p=config.gpt_top_p,
                                        #  max_tokens=config.gpt_max_tokens,
                                         n=1, stop=None)
    config.total_token += res.usage.total_tokens
    return res.choices[0].message.content
