
// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MODEL_MANAGER = "0x6dcd95F868061AE163bb612392FeaB69BF86E76a";

const RegisterInitialModels = buildModule("RegisterInitialModels", (m) => {
  const modelManagerAddr = m.getParameter("modelManager", MODEL_MANAGER);

  const modelManager = m.contractAt("ModelManagerUpgradeable", modelManagerAddr, { id: "modelManager" });

  // Register APIs
  const API_NAMESPACE = "api.system";
  const API_LLM_SIMPLETEXT = "llm-simpletext";
  const API_LLM_SIMPLEIMAGE = "llm-simpleimage";
  const MODE_NAMESPACE = "model.system";
  const MODE_LLM_SIMPLETEXT = "llm-simpletext";
  const MODE_LLM_SIMPLEIMAGE = "llm-simpleimage";

  m.call(modelManager, "registerModelAPI", [API_NAMESPACE, API_LLM_SIMPLETEXT, "string[] -> string",
    "prompt: string[] /* prompt */ -> returns: string /* LLM response */"]);
  m.call(modelManager, "registerModelAPI", [API_NAMESPACE, API_LLM_SIMPLEIMAGE, "string[], uint64, uint64 -> bytes",
    "prompt: string[] /* prompt */, image_width: uint64 /* image width */, image_height: uint64 /* image height */ -> image: bytes /* Generated image */"]);
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, MODE_LLM_SIMPLETEXT, API_NAMESPACE + "." + API_LLM_SIMPLETEXT]);
  m.call(modelManager, "registerModel", [MODE_NAMESPACE, MODE_LLM_SIMPLEIMAGE, API_NAMESPACE + "." + API_LLM_SIMPLEIMAGE]);

  return { modelManager };
});

export default RegisterInitialModels;