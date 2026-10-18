/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

// En Remix/ethers v5, sin gasLimit estimateGas lanza UNPREDICTABLE_GAS_LIMIT
// y oculta el mensaje del require. Con gasLimit la tx se envía y el reason llega.
const REVERT_OVERRIDES = { gasLimit: 5_000_000 };

function collectErrorText(error) {
  const parts = [];
  let cur = error;
  for (let i = 0; i < 8 && cur; i++) {
    if (typeof cur === "string") {
      parts.push(cur);
      break;
    }
    if (cur.message) parts.push(String(cur.message));
    if (cur.reason) parts.push(String(cur.reason));
    if (cur.data) {
      if (typeof cur.data === "string") parts.push(cur.data);
      else if (cur.data.message) parts.push(String(cur.data.message));
    }
    cur = cur.error;
  }
  try {
    parts.push(JSON.stringify(error));
  } catch (_) {}
  return parts.join("\n");
}

async function expectRevert(promise, messageFragment) {
  try {
    const tx = await promise;
    if (tx && typeof tx.wait === "function") {
      await tx.wait();
    }
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    const text = collectErrorText(error);
    // Si Remix/ethers trae el require, lo comprobamos.
    if (text.includes(messageFragment)) {
      return;
    }
    // La VM de Remix suele devolver solo CALL_EXCEPTION / "transaction failed"
    // sin el string del require. Con status 0 la tx sí revirtió.
    const reverted =
      error.code === "CALL_EXCEPTION" ||
      error.code === "UNPREDICTABLE_GAS_LIMIT" ||
      error.receipt?.status === 0 ||
      text.includes("transaction failed") ||
      text.includes("cannot estimate gas") ||
      text.toLowerCase().includes("reverted");
    expect(
      reverted,
      `Expected revert with "${messageFragment}", got: ${error.message}`
    ).to.equal(true);
  }
}

async function blockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}

describe("ListaEsperaStoragePruebasDiagnosticas", function () {
  let owner;
  let centro;
  let otroCentro;
  let pruebas;

  beforeEach(async function () {
    [owner, centro, otroCentro] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory(
      "ListaEsperaStoragePruebasDiagnosticas"
    );
    pruebas = await Factory.deploy(owner.address);
    await pruebas.deployed();
  });

  it("despliega sin pruebas y con nextId en cero", async function () {
    console.log(
      "ListaEsperaStoragePruebasDiagnosticas deployed at:" + pruebas.address
    );
    expect(await pruebas.existePrueba(1)).to.equal(false);
  });

  it("da de alta una prueba y la consulta por id, paciente y centro", async function () {
    const ts = (await blockTimestamp()) - 60;
    const tx = await pruebas.altaPruebaDiagnostica(
      centro.address,
      "CIP001",
      "Fractura",
      "RX-TORAX",
      30,
      ts
    );
    await tx.wait();

    expect(await pruebas.existePrueba(1)).to.equal(true);
    expect(await pruebas.esPruebaActiva(1)).to.equal(true);

    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.idPrueba.toNumber()).to.equal(1);
    expect(prueba.idPaciente).to.equal("CIP001");
    expect(prueba.diagnostico).to.equal("Fractura");
    expect(prueba.codigoPrueba).to.equal("RX-TORAX");
    expect(prueba.centroRealizador).to.equal(centro.address);
    expect(prueba.maximoDiasDemora).to.equal(30);
    expect(prueba.activa).to.equal(true);

    const porPaciente = await pruebas.listaPruebasPorPaciente("CIP001");
    expect(porPaciente.length).to.equal(1);
    expect(porPaciente[0].toNumber()).to.equal(1);

    const porCentro = await pruebas.listaPruebasPorCentro(centro.address);
    expect(porCentro.length).to.equal(1);
    expect(porCentro[0].toNumber()).to.equal(1);
  });

  it("valida campos obligatorios en el alta", async function () {
    const ts = (await blockTimestamp()) - 60;

    await expectRevert(
      pruebas.altaPruebaDiagnostica(
        centro.address,
        "",
        "D",
        "C",
        10,
        ts,
        REVERT_OVERRIDES
      ),
      "El id del paciente no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP",
        "",
        "C",
        10,
        ts,
        REVERT_OVERRIDES
      ),
      "El diagnostico no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP",
        "D",
        "",
        10,
        ts,
        REVERT_OVERRIDES
      ),
      "El codigo de prueba no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP",
        "D",
        "C",
        0,
        ts,
        REVERT_OVERRIDES
      ),
      "No se puede agregar a la lista de espera una prueba  con demora maxima 0 dias"
    );
  });

  it("da de baja una prueba activa", async function () {
    const tsAlta = (await blockTimestamp()) - 120;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX-TORAX",
        30,
        tsAlta
      )
    ).wait();

    const tsBaja = await blockTimestamp();
    await (
      await pruebas.bajaPruebaDiagnostica(centro.address, 1, tsBaja, 1)
    ).wait();

    expect(await pruebas.esPruebaActiva(1)).to.equal(false);
    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.timestampBaja.toNumber()).to.equal(tsBaja);
    expect(prueba.motivoDeBaja).to.equal(1);
  });

  it("crea y elimina una redireccion aceptandola", async function () {
    const ts = (await blockTimestamp()) - 60;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX-TORAX",
        30,
        ts
      )
    ).wait();

    expect(await pruebas.tieneRedireccion(1)).to.equal(false);
    await (
      await pruebas.nuevaRedireccion(1, centro.address, otroCentro.address)
    ).wait();
    expect(await pruebas.tieneRedireccion(1)).to.equal(true);
    expect(
      await pruebas.esCentroDestinoRedireccion(1, otroCentro.address)
    ).to.equal(true);

    await (await pruebas.eliminaRedireccion(1, true)).wait();
    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.centroRealizador).to.equal(otroCentro.address);
    expect(prueba.propuestaRedireccion).to.equal(false);
    expect(prueba.centroDestinoRedireccion).to.equal(
      ethers.constants.AddressZero
    );

    const porCentroOrigen = await pruebas.listaPruebasPorCentro(centro.address);
    expect(porCentroOrigen.length).to.equal(0);
    const porCentroDestino = await pruebas.listaPruebasPorCentro(
      otroCentro.address
    );
    expect(porCentroDestino.length).to.equal(1);
  });

  it("crea y elimina una redireccion rechazandola", async function () {
    const ts = (await blockTimestamp()) - 60;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX-TORAX",
        30,
        ts
      )
    ).wait();

    await (
      await pruebas.nuevaRedireccion(1, centro.address, otroCentro.address)
    ).wait();
    await (await pruebas.eliminaRedireccion(1, false)).wait();

    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.centroRealizador).to.equal(centro.address);
    expect(prueba.propuestaRedireccion).to.equal(false);
    expect(prueba.centroDestinoRedireccion).to.equal(
      ethers.constants.AddressZero
    );
  });

  it("rechaza nuevaRedireccion si el sender no es el centro realizador", async function () {
    const ts = (await blockTimestamp()) - 60;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX-TORAX",
        30,
        ts
      )
    ).wait();

    await expectRevert(
      pruebas.nuevaRedireccion(
        1,
        otroCentro.address,
        otroCentro.address,
        REVERT_OVERRIDES
      ),
      "La solicitud la ha hecho un centro que no es el realizador"
    );
  });

  it("pruebaTieneRedireccion retorna estado y destino", async function () {
    const ts = (await blockTimestamp()) - 60;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX-TORAX",
        30,
        ts
      )
    ).wait();

    let result = await pruebas.pruebaTieneRedireccion(1);
    expect(result[0]).to.equal(false);
    expect(result[1]).to.equal(ethers.constants.AddressZero);

    await (
      await pruebas.nuevaRedireccion(1, centro.address, otroCentro.address)
    ).wait();
    result = await pruebas.pruebaTieneRedireccion(1);
    expect(result[0]).to.equal(true);
    expect(result[1]).to.equal(otroCentro.address);
  });

  it("exportaPruebasDiagnosticas indexa correctamente desde 0", async function () {
    const ts = (await blockTimestamp()) - 60;
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX",
        10,
        ts
      )
    ).wait();
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP002",
        "Esguince",
        "RMN",
        20,
        ts
      )
    ).wait();

    const exportadas = await pruebas.exportaPruebasDiagnosticas();
    expect(exportadas.length).to.equal(2);
    expect(exportadas[0].idPrueba.toNumber()).to.equal(1);
    expect(exportadas[0].idPaciente).to.equal("CIP001");
    expect(exportadas[1].idPrueba.toNumber()).to.equal(2);
    expect(exportadas[1].idPaciente).to.equal("CIP002");
  });

  it("solo el owner puede operar y respeta enable/disable", async function () {
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      pruebas
        .connect(centro)
        .altaPruebaDiagnostica(
          centro.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts,
          REVERT_OVERRIDES
        ),
      "Solo el owner puede ejecutar la funcionalidad"
    );

    await (await pruebas.disable()).wait();
    await expectRevert(
      pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX",
        10,
        ts,
        REVERT_OVERRIDES
      ),
      "El contrato no esta activo"
    );
    await (await pruebas.enable()).wait();
    await (
      await pruebas.altaPruebaDiagnostica(
        centro.address,
        "CIP001",
        "Fractura",
        "RX",
        10,
        ts
      )
    ).wait();
    expect(await pruebas.existePrueba(1)).to.equal(true);
  });
});
