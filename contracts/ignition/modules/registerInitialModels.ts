
// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MODEL_MANAGER = "0x27d0BAEcb181c3bB1B5850049092D40eE7b1fE3d";

const RegisterInitialModels = buildModule("RegisterInitialModels", (m) => {
  const modelManagerAddr = m.getParameter("modelManager", MODEL_MANAGER);

  const modelManager = m.contractAt("ModelManagerUpgradeable", modelManagerAddr, { id: "modelManager" });

  // Register APIs
  const API_NAMESPACE = "api.system";
  const API_LLM_SIMPLETEXT = "llm-simpletext";
  const API_LLM_SIMPLEIMAGE = "llm-simpleimage";
  const MODE_NAMESPACE = "model.system";
  const OPEN_AI_IMAGE = 'openai-gpt-image-1'
  const OPEN_AI_GPT5 = 'openai-gpt-5'
  const OPEN_AI_GPT5_MINI = 'openai-gpt-5-mini'
  const OPEN_AI_GPT5_NANO = 'openai-gpt-5-nano'

  m.call(modelManager, "registerModelAPI", [API_NAMESPACE, API_LLM_SIMPLETEXT, "string[] -> string",
    "prompt: string[] /* prompt */ -> returns: string /* LLM response */"], { id: "registerModelAPI1" });
  m.call(modelManager, "registerModelAPI", [API_NAMESPACE, API_LLM_SIMPLEIMAGE, "string[], uint64, uint64 -> bytes",
    "prompt: string[] /* prompt */, image_width: uint64 /* image width */, image_height: uint64 /* image height */ -> image: bytes /* Generated image */"],
    { id: "registerModelAPI2" });
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, OPEN_AI_GPT5_NANO, API_NAMESPACE + "." + API_LLM_SIMPLETEXT], { id: "registerModel1" });
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, OPEN_AI_GPT5_MINI, API_NAMESPACE + "." + API_LLM_SIMPLETEXT], { id: "registerModel2" });
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, OPEN_AI_GPT5, API_NAMESPACE + "." + API_LLM_SIMPLETEXT], { id: "registerModel3" });
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, OPEN_AI_IMAGE, API_NAMESPACE + "." + API_LLM_SIMPLEIMAGE], { id: "registerModel4" });

  return { modelManager };
});

export default RegisterInitialModels;