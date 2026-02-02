<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

const route = useRoute()
const router = useRouter()
const operadora = ref({})
const despesas = ref([])
const loading = ref(true)

const openAccordions = ref({})

const toggleAccordion = (key) => {
  openAccordions.value[key] = !openAccordions.value[key]
}

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}

const groupedDespesas = computed(() => {
  const groups = {}
  
  despesas.value.forEach(item => {
    const key = `${item.ano}-${item.trimestre}`
    
    if (!groups[key]) {
      groups[key] = {
        ano: item.ano,
        trimestre: item.trimestre,
        total: 0,
        items: []
      }
    }
    
    groups[key].items.push(item)
    const val = parseFloat(item.valor_despesa) || 0
    groups[key].total += val
  })

  return Object.values(groups).sort((a, b) => {
    if (a.ano !== b.ano) return b.ano - a.ano
    return b.trimestre - a.trimestre
  })
})

onMounted(async () => {
  const cnpj = route.params.cnpj
  try {
    const resOp = await fetch(`http://localhost:5000/api/operadoras/${cnpj}`)
    operadora.value = await resOp.json()

    const resDesp = await fetch(`http://localhost:5000/api/operadoras/${cnpj}/despesas`)
    despesas.value = await resDesp.json()
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="container mx-auto px-6 py-10 max-w-4xl">
    <button @click="router.back()" class="mb-6 text-sm text-slate-400 hover:text-brand-500 flex items-center gap-2 transition-colors">
      &larr; Voltar
    </button>

    <div v-if="loading" class="animate-pulse h-64 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>

    <div v-else class="space-y-8">
      <div class="bg-slate-900 p-8 rounded-2xl shadow-xl border border-slate-700 relative overflow-hidden">
        <div class="absolute top-0 right-0 w-64 h-64 bg-brand-500/10 rounded-full blur-3xl -mr-16 -mt-16 pointer-events-none"></div>
        
        <h1 class="text-3xl font-bold text-white mb-2 relative z-10">{{ operadora.razao_social }}</h1>
        <p class="text-slate-400 text-sm mb-6">Informações Cadastrais da Operadora</p>
        
        <div class="flex flex-wrap gap-3 text-sm font-medium relative z-10">
          <div class="bg-white/10 backdrop-blur-md text-white px-4 py-2 rounded-lg border border-white/10 shadow-sm flex items-center gap-2">
            <span class="opacity-60 text-xs uppercase tracking-wide">CNPJ</span>
            <span class="font-mono">{{ operadora.cnpj }}</span>
          </div>
          <div class="bg-white/10 backdrop-blur-md text-white px-4 py-2 rounded-lg border border-white/10 shadow-sm flex items-center gap-2">
            <span class="opacity-60 text-xs uppercase tracking-wide">Registro ANS</span>
            <span class="font-mono">{{ operadora.reg_ans }}</span>
          </div>
          <div class="bg-white/10 backdrop-blur-md text-white px-4 py-2 rounded-lg border border-white/10 shadow-sm flex items-center gap-2">
            <span class="opacity-60 text-xs uppercase tracking-wide">UF</span>
            <span class="font-bold">{{ operadora.uf }}</span>
          </div>
        </div>
      </div>

      <div class="space-y-4">
        <div class="flex items-center justify-between px-2">
          <h3 class="font-bold text-xl text-slate-800 dark:text-white">Histórico Financeiro</h3>
          <span class="text-xs text-slate-500 uppercase tracking-wide font-bold">Agrupado por Trimestre</span>
        </div>
        
        <div v-if="despesas.length === 0" class="p-12 text-center text-slate-400 bg-white dark:bg-slate-800 rounded-2xl border border-dashed border-slate-300 dark:border-slate-700">
          Nenhum registro de despesa encontrado para esta operadora.
        </div>

        <div 
          v-for="group in groupedDespesas" 
          :key="`${group.ano}-${group.trimestre}`"
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden transition-all duration-300"
        >
          <button 
            @click="toggleAccordion(`${group.ano}-${group.trimestre}`)"
            class="w-full flex justify-between items-center p-5 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors text-left group"
          >
            <div class="flex items-center gap-4">
              <div class="bg-brand-50 dark:bg-brand-900/20 text-brand-600 dark:text-brand-400 p-3 rounded-xl group-hover:bg-brand-100 dark:group-hover:bg-brand-900/40 transition-colors">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
              </div>
              <div>
                <p class="text-lg font-bold text-slate-800 dark:text-white">{{ group.ano }} - {{ group.trimestre }}º Trimestre</p>
                <p class="text-sm text-slate-500">{{ group.items.length }} lançamentos contábeis</p>
              </div>
            </div>
            
            <div class="flex items-center gap-6">
              <div class="text-right hidden sm:block">
                <p class="text-[10px] text-slate-400 uppercase tracking-widest font-bold">Total do Período</p>
                <p class="text-lg font-bold text-emerald-600 dark:text-emerald-400">{{ formatCurrency(group.total) }}</p>
              </div>
              <svg 
                class="w-5 h-5 text-slate-400 transform transition-transform duration-300"
                :class="{'rotate-180': openAccordions[`${group.ano}-${group.trimestre}`]}"
                fill="none" stroke="currentColor" viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          </button>

          <div v-show="openAccordions[`${group.ano}-${group.trimestre}`]" class="border-t border-slate-100 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-900/30">
            <table class="w-full text-left text-sm">
              <thead class="text-slate-400 font-medium text-xs uppercase border-b border-slate-100 dark:border-slate-700">
                <tr>
                  <th class="px-6 py-3 pl-24">Tipo de Despesa</th>
                  <th class="px-6 py-3 text-right">Valor</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <tr v-for="(item, idx) in group.items" :key="idx" class="hover:bg-slate-100 dark:hover:bg-slate-800/50 transition-colors">
                  <td class="px-6 py-3 pl-24 text-slate-600 dark:text-slate-300">Despesa Assistencial / Operacional</td>
                  <td class="px-6 py-3 text-right font-mono text-slate-700 dark:text-slate-200">{{ formatCurrency(item.valor_despesa) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>