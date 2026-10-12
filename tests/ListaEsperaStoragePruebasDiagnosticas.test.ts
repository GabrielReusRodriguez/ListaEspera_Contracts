/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

async function expectRevert(promise, messageFragment) {
  try {
    await promise;
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    expect(error.message).to.include(messageFragment);
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
      pruebas.altaPruebaDiagnostica(centro.address, "", "D", "C", 10, ts),
      "El id del paciente no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(centro.address, "CIP", "", "C", 10, ts),
      "El diagnostico no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(centro.address, "CIP", "D", "", 10, ts),
      "El codigo de prueba no puede estar vacio"
    );
    await expectRevert(
      pruebas.altaPruebaDiagnostica(centro.address, "CIP", "D", "C", 0, ts),
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
    await (await pruebas.nuevaRedireccion(1, otroCentro.address)).wait();
    expect(await pruebas.tieneRedireccion(1)).to.equal(true);
    expect(
      await pruebas.esCentroDestinoRedireccion(1, otroCentro.address)
    ).to.equal(true);

    await (await pruebas.eliminaRedireccion(1, true)).wait();
    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.centroRealizador).to.equal(otroCentro.address);
    expect(prueba.centroDestinoRedireccion).to.equal(
      ethers.constants.AddressZero
    );
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

    await (await pruebas.nuevaRedireccion(1, otroCentro.address)).wait();
    await (await pruebas.eliminaRedireccion(1, false)).wait();

    const prueba = await pruebas.getPruebaDiagnostica(1);
    expect(prueba.centroRealizador).to.equal(centro.address);
    expect(prueba.centroDestinoRedireccion).to.equal(
      ethers.constants.AddressZero
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

    await (await pruebas.nuevaRedireccion(1, otroCentro.address)).wait();
    result = await pruebas.pruebaTieneRedireccion(1);
    expect(result[0]).to.equal(true);
    expect(result[1]).to.equal(otroCentro.address);
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
          ts
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
        ts
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
